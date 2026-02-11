import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedUserId } from '@/lib/mobile-auth';
import { registerDeviceToken } from '@/lib/dynamodb-users';

/**
 * POST /api/mobile/notifications/register
 *
 * Register device token for push notifications
 */
export async function POST(request: NextRequest) {
  try {
    // Authenticate user
    const userId = await getAuthenticatedUserId(request);

    // Parse request body
    const body = await request.json();
    const { deviceToken, platform } = body;

    if (!deviceToken || !platform) {
      return NextResponse.json(
        { error: 'Missing required fields: deviceToken, platform' },
        { status: 400 }
      );
    }

    if (platform !== 'ios' && platform !== 'android') {
      return NextResponse.json(
        { error: 'Invalid platform. Must be "ios" or "android"' },
        { status: 400 }
      );
    }

    // Save device token to user record
    await registerDeviceToken(userId, deviceToken, platform);

    console.log(`Registered push notification token for user ${userId} (${platform})`);

    return NextResponse.json({
      success: true,
      message: 'Device token registered successfully',
    });
  } catch (error) {
    console.error('Error registering device token:', error);
    return NextResponse.json(
      { error: 'Failed to register device token' },
      { status: 500 }
    );
  }
}
