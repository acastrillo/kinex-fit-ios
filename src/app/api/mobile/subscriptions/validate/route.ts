import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedUserId } from '@/lib/mobile-auth';
import { updateUserSubscription, getUserById } from '@/lib/dynamodb-users';

/**
 * POST /api/mobile/subscriptions/validate
 *
 * Validates App Store receipt and updates user subscription
 */
export async function POST(request: NextRequest) {
  try {
    // Authenticate user
    const userId = await getAuthenticatedUserId(request);

    // Parse request body
    const body = await request.json();
    const { transactionId, productId, receiptData } = body;

    if (!transactionId || !productId || !receiptData) {
      return NextResponse.json(
        { error: 'Missing required fields: transactionId, productId, receiptData' },
        { status: 400 }
      );
    }

    // Verify receipt with Apple
    const verificationResult = await verifyReceiptWithApple(receiptData);

    if (!verificationResult.isValid) {
      return NextResponse.json(
        { error: 'Receipt verification failed', details: verificationResult.error },
        { status: 400 }
      );
    }

    // Map product ID to subscription tier
    const tier = mapProductIdToTier(productId);
    if (!tier) {
      return NextResponse.json(
        { error: 'Invalid product ID' },
        { status: 400 }
      );
    }

    // Get subscription expiration from receipt
    const expiresAt = verificationResult.expiresDate || null;

    // Update user subscription in DynamoDB
    await updateUserSubscription(userId, {
      subscriptionTier: tier,
      subscriptionStatus: 'active',
      subscriptionExpiresAt: expiresAt,
      lastReceiptValidation: new Date().toISOString(),
    });

    // Get updated user
    const user = await getUserById(userId);
    if (!user) {
      return NextResponse.json(
        { error: 'User not found after update' },
        { status: 500 }
      );
    }

    // Return updated subscription info
    return NextResponse.json({
      subscriptionTier: user.subscriptionTier,
      subscriptionStatus: user.subscriptionStatus,
      subscriptionExpiresAt: user.subscriptionExpiresAt,
    });
  } catch (error) {
    console.error('Receipt validation error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// MARK: - Apple Receipt Verification

interface ReceiptVerificationResult {
  isValid: boolean;
  expiresDate?: string;
  error?: string;
}

/**
 * Verify receipt with Apple's verifyReceipt endpoint
 * https://developer.apple.com/documentation/appstorereceipts/verifyreceipt
 */
async function verifyReceiptWithApple(
  receiptData: string
): Promise<ReceiptVerificationResult> {
  // Determine environment (production or sandbox)
  const isProduction = process.env.NODE_ENV === 'production';
  const verifyURL = isProduction
    ? 'https://buy.itunes.apple.com/verifyReceipt'
    : 'https://sandbox.itunes.apple.com/verifyReceipt';

  // App Store shared secret (from App Store Connect)
  const sharedSecret = process.env.APP_STORE_SHARED_SECRET;
  if (!sharedSecret) {
    console.error('APP_STORE_SHARED_SECRET environment variable not set');
    return { isValid: false, error: 'Server configuration error' };
  }

  try {
    const response = await fetch(verifyURL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        'receipt-data': receiptData,
        password: sharedSecret,
        'exclude-old-transactions': true,
      }),
    });

    const result = await response.json();

    // Status codes:
    // 0: Valid receipt
    // 21007: Sandbox receipt sent to production (retry with sandbox)
    // 21008: Production receipt sent to sandbox (retry with production)
    if (result.status === 21007 && isProduction) {
      // Retry with sandbox
      return await verifyWithSandbox(receiptData, sharedSecret);
    }

    if (result.status !== 0) {
      console.error('Apple receipt verification failed:', result);
      return { isValid: false, error: `Apple verification status: ${result.status}` };
    }

    // Extract subscription info from latest receipt
    const latestReceiptInfo = result.latest_receipt_info?.[0];
    if (!latestReceiptInfo) {
      return { isValid: false, error: 'No subscription info in receipt' };
    }

    // Check if subscription is active
    const expiresDate = latestReceiptInfo.expires_date_ms
      ? new Date(parseInt(latestReceiptInfo.expires_date_ms)).toISOString()
      : undefined;

    // Check if expired
    if (expiresDate && new Date(expiresDate) < new Date()) {
      return { isValid: false, error: 'Subscription expired' };
    }

    return {
      isValid: true,
      expiresDate,
    };
  } catch (error) {
    console.error('Error verifying receipt with Apple:', error);
    return { isValid: false, error: 'Network error' };
  }
}

/**
 * Retry verification with sandbox environment
 */
async function verifyWithSandbox(
  receiptData: string,
  sharedSecret: string
): Promise<ReceiptVerificationResult> {
  try {
    const response = await fetch('https://sandbox.itunes.apple.com/verifyReceipt', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        'receipt-data': receiptData,
        password: sharedSecret,
        'exclude-old-transactions': true,
      }),
    });

    const result = await response.json();

    if (result.status !== 0) {
      return { isValid: false, error: `Sandbox verification status: ${result.status}` };
    }

    const latestReceiptInfo = result.latest_receipt_info?.[0];
    const expiresDate = latestReceiptInfo?.expires_date_ms
      ? new Date(parseInt(latestReceiptInfo.expires_date_ms)).toISOString()
      : undefined;

    return {
      isValid: true,
      expiresDate,
    };
  } catch (error) {
    console.error('Sandbox verification error:', error);
    return { isValid: false, error: 'Sandbox network error' };
  }
}

// MARK: - Product ID Mapping

/**
 * Map App Store product ID to subscription tier
 */
function mapProductIdToTier(productId: string): string | null {
  const tierMap: Record<string, string> = {
    'com.kinex.fit.core.monthly': 'core',
    'com.kinex.fit.pro.monthly': 'pro',
    'com.kinex.fit.elite.monthly': 'elite',
  };

  return tierMap[productId] || null;
}
