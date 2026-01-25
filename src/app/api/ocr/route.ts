// app/api/ocr/route.ts
export const runtime = 'nodejs'; // ensure Node runtime (AWS SDK needs Node)
import { NextResponse } from 'next/server';
import { TextractClient, DetectDocumentTextCommand } from '@aws-sdk/client-textract';
import { getAuthenticatedUserId } from '@/lib/api-auth';
import { dynamoDBUsers } from '@/lib/dynamodb';
import { getQuotaLimit, normalizeSubscriptionTier } from '@/lib/stripe';
import { checkRateLimit } from '@/lib/rate-limit';
import { hasRole } from '@/lib/rbac';
import { isWeeklyResetDue } from '@/lib/quota-reset';

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB (Textract sync limit)
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'application/pdf'];

function validateDocumentSignature(header: Uint8Array): boolean {
  // JPEG
  if (header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff) return true;
  // PNG
  if (header[0] === 0x89 && header[1] === 0x50 && header[2] === 0x4e && header[3] === 0x47) return true;
  // PDF
  if (header[0] === 0x25 && header[1] === 0x50 && header[2] === 0x44 && header[3] === 0x46) return true;
  return false;
}

// Helper function to create Textract client lazily
function getTextractClient() {
  return new TextractClient({
    region: process.env.AWS_REGION || 'us-east-1',
    credentials: process.env.AWS_ACCESS_KEY_ID
      ? {
          accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
          sessionToken: process.env.AWS_SESSION_TOKEN,
        }
      : undefined, // Falls back to AWS CLI credentials
  });
}

export async function POST(req: Request) {
  try {
    // SECURITY FIX: Use new auth utility
    const auth = await getAuthenticatedUserId();
    if ('error' in auth) return auth.error;
    const { userId } = auth;

    // RATE LIMITING: Check rate limit (10 OCR requests per hour)
    const rateLimit = await checkRateLimit(userId, 'api:ocr');
    if (!rateLimit.success) {
      return NextResponse.json(
        {
          error: 'Too many OCR requests',
          message: 'You have exceeded the rate limit for OCR processing. Please try again later.',
          limit: rateLimit.limit,
          remaining: rateLimit.remaining,
          reset: rateLimit.reset,
        },
        {
          status: 429,
          headers: {
            'X-RateLimit-Limit': rateLimit.limit.toString(),
            'X-RateLimit-Remaining': rateLimit.remaining.toString(),
            'X-RateLimit-Reset': rateLimit.reset.toString(),
          },
        }
      );
    }

    // Check OCR quota
    const user = await dynamoDBUsers.get(userId);
    if (!user) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    // ADMIN BYPASS: Admins have unlimited quotas
    const isAdmin = hasRole(user, 'admin');

    // Get quota limit based on subscription tier
    const tier = normalizeSubscriptionTier(user.subscriptionTier);
    const weeklyLimit = getQuotaLimit(tier, 'ocrQuotaWeekly');

    let ocrUsed = user.ocrQuotaUsed || 0;
    if (!isAdmin && weeklyLimit !== null && isWeeklyResetDue(user.ocrQuotaResetDate)) {
      await dynamoDBUsers.resetOCRQuota(userId);
      ocrUsed = 0;
    }

    if (!isAdmin && weeklyLimit !== null && weeklyLimit <= 0) {
      return NextResponse.json(
        {
          error: 'OCR quota exceeded',
          message: 'You have reached your weekly OCR limit. Upgrade your subscription for more scans.',
          quotaUsed: ocrUsed,
          quotaLimit: weeklyLimit,
          subscriptionTier: user.subscriptionTier
        },
        { status: 429 }
      );
    }

    const form = await req.formData(); // supported by Route Handlers
    const file = form.get('file');
    if (!(file instanceof Blob)) {
      return NextResponse.json({ error: 'file is required' }, { status: 400 });
    }

    if (file.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        {
          error: 'File too large',
          message: `Maximum file size is ${MAX_FILE_SIZE / 1024 / 1024}MB`,
        },
        { status: 400 }
      );
    }

    if (file.type && !ALLOWED_MIME_TYPES.includes(file.type)) {
      return NextResponse.json(
        {
          error: 'Invalid file type',
          message: 'Only JPEG, PNG, and PDF files are allowed',
        },
        { status: 400 }
      );
    }

    const arrayBuffer = await file.arrayBuffer();
    const header = new Uint8Array(arrayBuffer.slice(0, 4));
    if (!validateDocumentSignature(header)) {
      return NextResponse.json(
        {
          error: 'Invalid document file',
          message: 'File does not appear to be a valid image or PDF',
        },
        { status: 400 }
      );
    }

    const bytes = Buffer.from(arrayBuffer);

    let ocrUsedAfter = ocrUsed;
    if (!isAdmin && weeklyLimit !== null) {
      const consumeResult = await dynamoDBUsers.consumeQuota(userId, 'ocrQuotaUsed', weeklyLimit);
      if (!consumeResult.success) {
        return NextResponse.json(
          {
            error: 'OCR quota exceeded',
            message: 'You have reached your weekly OCR limit. Upgrade your subscription for more scans.',
            quotaUsed: ocrUsed,
            quotaLimit: weeklyLimit,
            subscriptionTier: user.subscriptionTier
          },
          { status: 429 }
        );
      }
      ocrUsedAfter = consumeResult.newValue ?? ocrUsed + 1;
    }
    const cmd = new DetectDocumentTextCommand({
      Document: { Bytes: bytes }, // Textract allows bytes or S3Object
    });

    // Initialize client only when needed (lazy loading)
    const client = getTextractClient();
    const out = await client.send(cmd);

    // Concatenate detected LINE blocks into text; average confidence if present
    const lines = (out.Blocks || [])
      .filter(b => b.BlockType === 'LINE' && b.Text)
      .map(b => ({ text: b.Text!, conf: b.Confidence ?? undefined }));

    const text = lines.map(l => l.text).join('\n');
    const confidence =
      lines.length
        ? Math.round((lines.reduce((s, l) => s + (l.conf ?? 0), 0) / lines.length) * 10) / 10
        : undefined;

    // Get updated quota info
    const currentLimit = isAdmin ? null : getQuotaLimit(tier, 'ocrQuotaWeekly');

    return NextResponse.json({
      text,
      confidence,
      quotaUsed: isAdmin ? ocrUsed : ocrUsedAfter,
      quotaLimit: currentLimit,
      isUnlimited: isAdmin || currentLimit === null
    });
  } catch (err: unknown) {
    return NextResponse.json({ error: String((err as Error)?.message || err) }, { status: 500 });
  }
}
