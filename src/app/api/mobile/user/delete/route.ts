import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedUserId } from '@/lib/mobile-auth';
import { deleteUser } from '@/lib/dynamodb-users';
import { deleteAllUserWorkouts } from '@/lib/dynamodb-workouts';
import { deleteAllUserMetrics } from '@/lib/dynamodb-body-metrics';

/**
 * DELETE /api/mobile/user/delete
 *
 * Permanently deletes user account and all associated data
 *
 * IMPORTANT: This is irreversible and will delete:
 * - User profile data
 * - All workouts
 * - All body metrics
 * - Subscription information
 * - Personal records
 * - Training preferences
 */
export async function DELETE(request: NextRequest) {
  try {
    // Authenticate user
    const userId = await getAuthenticatedUserId(request);

    console.log(`Account deletion requested for user: ${userId}`);

    // Delete all user data from DynamoDB
    await Promise.all([
      deleteAllUserWorkouts(userId),
      deleteAllUserMetrics(userId),
      deleteUser(userId),
    ]);

    console.log(`Account deletion complete for user: ${userId}`);

    // Return success (tokens will be cleared client-side)
    return NextResponse.json({
      success: true,
      message: 'Account deleted successfully',
    });
  } catch (error) {
    console.error('Account deletion error:', error);

    // Return generic error to avoid leaking information
    return NextResponse.json(
      { error: 'Failed to delete account' },
      { status: 500 }
    );
  }
}
