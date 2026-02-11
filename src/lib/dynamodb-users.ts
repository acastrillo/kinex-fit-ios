import { dynamoDBUsers, DynamoDBUser } from './dynamodb';

export type { DynamoDBUser };

export interface UpdateSubscriptionInput {
  subscriptionTier: string;
  subscriptionStatus: string;
  subscriptionExpiresAt: string | null;
  lastReceiptValidation: string;
}

/**
 * Get user by ID
 */
export async function getUserById(userId: string): Promise<DynamoDBUser | null> {
  try {
    const result = await dynamoDBUsers.get({
      userId,
    });

    return result.Item as DynamoDBUser || null;
  } catch (error) {
    console.error('Error getting user:', error);
    throw error;
  }
}

/**
 * Update user subscription information
 */
export async function updateUserSubscription(
  userId: string,
  subscription: UpdateSubscriptionInput
): Promise<void> {
  try {
    const now = new Date().toISOString();

    await dynamoDBUsers.update({
      Key: { userId },
      UpdateExpression: `
        SET subscriptionTier = :tier,
            subscriptionStatus = :status,
            subscriptionExpiresAt = :expiresAt,
            lastReceiptValidation = :lastValidation,
            updatedAt = :updatedAt
      `,
      ExpressionAttributeValues: {
        ':tier': subscription.subscriptionTier,
        ':status': subscription.subscriptionStatus,
        ':expiresAt': subscription.subscriptionExpiresAt,
        ':lastValidation': subscription.lastReceiptValidation,
        ':updatedAt': now,
      },
    });

    console.log(`Updated subscription for user ${userId}:`, subscription);
  } catch (error) {
    console.error('Error updating user subscription:', error);
    throw error;
  }
}

/**
 * Update user quotas
 */
export async function incrementUserQuota(
  userId: string,
  quotaType: 'scan' | 'ai'
): Promise<void> {
  try {
    const now = new Date().toISOString();
    const quotaField = quotaType === 'scan' ? 'scanQuotaUsed' : 'aiQuotaUsed';

    await dynamoDBUsers.update({
      Key: { userId },
      UpdateExpression: `
        SET ${quotaField} = ${quotaField} + :increment,
            updatedAt = :updatedAt
      `,
      ExpressionAttributeValues: {
        ':increment': 1,
        ':updatedAt': now,
      },
    });

    console.log(`Incremented ${quotaType} quota for user ${userId}`);
  } catch (error) {
    console.error('Error incrementing user quota:', error);
    throw error;
  }
}

/**
 * Delete user permanently
 */
export async function deleteUser(userId: string): Promise<void> {
  try {
    await dynamoDBUsers.delete({
      Key: { userId },
    });

    console.log(`Deleted user: ${userId}`);
  } catch (error) {
    console.error('Error deleting user:', error);
    throw error;
  }
}

/**
 * Register device token for push notifications
 */
export async function registerDeviceToken(
  userId: string,
  deviceToken: string,
  platform: 'ios' | 'android'
): Promise<void> {
  try {
    const now = new Date().toISOString();

    await dynamoDBUsers.update({
      Key: { userId },
      UpdateExpression: `
        SET pushNotificationToken = :token,
            pushNotificationPlatform = :platform,
            pushNotificationRegisteredAt = :registeredAt,
            updatedAt = :updatedAt
      `,
      ExpressionAttributeValues: {
        ':token': deviceToken,
        ':platform': platform,
        ':registeredAt': now,
        ':updatedAt': now,
      },
    });

    console.log(`Registered device token for user ${userId}`);
  } catch (error) {
    console.error('Error registering device token:', error);
    throw error;
  }
}
