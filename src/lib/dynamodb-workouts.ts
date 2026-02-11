import { dynamoDBWorkouts, DynamoDBWorkout } from './dynamodb';
import { v4 as uuidv4 } from 'uuid';

export type { DynamoDBWorkout };

export interface WorkoutInput {
  userId: string;
  workoutId?: string;
  title: string;
  description?: string | null;
  content: string;
  exercises: Array<{
    name: string;
    sets?: number | null;
    reps?: string | null;
    weight?: string | null;
    notes?: string | null;
  }>;
  source?: 'manual' | 'ocr' | 'instagram' | 'ai' | null;
  type?: string | null;
  totalDuration?: number | null;
  difficulty?: string | null;
  tags?: string[];
  scheduledDate?: string | null;
  status?: 'scheduled' | 'completed' | 'skipped' | null;
  completedDate?: string | null;
  imageUrls?: string[] | null;
  thumbnailUrl?: string | null;
  workoutType?: 'standard' | 'emom' | 'amrap' | 'rounds' | 'ladder' | 'tabata' | null;
  aiEnhanced?: boolean | null;
  aiNotes?: string[] | null;
  muscleGroups?: string[] | null;
}

export interface ListWorkoutsOptions {
  limit?: number;
  cursor?: string;
}

export interface ListWorkoutsResult {
  workouts: DynamoDBWorkout[];
  nextCursor?: string;
}

/**
 * Create a new workout
 */
export async function createWorkout(input: WorkoutInput): Promise<DynamoDBWorkout> {
  const workoutId = input.workoutId || uuidv4();

  const workout: Omit<DynamoDBWorkout, 'userId' | 'createdAt' | 'updatedAt'> & { createdAt?: string } = {
    workoutId,
    title: input.title,
    description: input.description || null,
    exercises: input.exercises || [],
    content: input.content,
    author: null,
    source: input.source || 'manual',
    type: input.type || null,
    totalDuration: input.totalDuration || null,
    difficulty: input.difficulty || null,
    tags: input.tags || [],
    llmData: null,
    imageUrls: input.imageUrls || null,
    thumbnailUrl: input.thumbnailUrl || null,
    scheduledDate: input.scheduledDate || null,
    status: input.status || null,
    completedDate: input.completedDate || null,
    workoutType: input.workoutType || null,
    structure: null,
    amrapBlocks: null,
    emomBlocks: null,
    timerConfig: null,
    blockTimers: null,
    aiEnhanced: input.aiEnhanced || null,
    aiNotes: input.aiNotes || null,
    muscleGroups: input.muscleGroups || null,
  };

  return await dynamoDBWorkouts.upsert(input.userId, workout);
}

/**
 * List workouts for a user with pagination
 */
export async function listWorkouts(
  userId: string,
  options?: ListWorkoutsOptions
): Promise<ListWorkoutsResult> {
  const limit = options?.limit || 50;

  // Note: cursor-based pagination would require implementing LastEvaluatedKey encoding/decoding
  // For now, we'll use simple limit-based pagination
  const workouts = await dynamoDBWorkouts.list(userId, limit);

  return {
    workouts,
    nextCursor: undefined, // TODO: Implement cursor-based pagination if needed
  };
}

/**
 * Get a specific workout
 */
export async function getWorkout(
  userId: string,
  workoutId: string
): Promise<DynamoDBWorkout | null> {
  return await dynamoDBWorkouts.get(userId, workoutId);
}

/**
 * Update a workout
 */
export async function updateWorkout(
  userId: string,
  workoutId: string,
  input: WorkoutInput
): Promise<DynamoDBWorkout> {
  // First get the existing workout to preserve fields not in the update
  const existing = await getWorkout(userId, workoutId);
  if (!existing) {
    throw new Error('Workout not found');
  }

  const workout: Omit<DynamoDBWorkout, 'userId' | 'createdAt' | 'updatedAt'> & { createdAt: string } = {
    workoutId,
    title: input.title,
    description: input.description || null,
    exercises: input.exercises || [],
    content: input.content,
    author: existing.author,
    createdAt: existing.createdAt,
    source: input.source || existing.source,
    type: input.type || existing.type,
    totalDuration: input.totalDuration !== undefined ? input.totalDuration : existing.totalDuration,
    difficulty: input.difficulty || existing.difficulty,
    tags: input.tags || existing.tags,
    llmData: existing.llmData,
    imageUrls: input.imageUrls !== undefined ? input.imageUrls : existing.imageUrls,
    thumbnailUrl: input.thumbnailUrl !== undefined ? input.thumbnailUrl : existing.thumbnailUrl,
    scheduledDate: input.scheduledDate !== undefined ? input.scheduledDate : existing.scheduledDate,
    status: input.status !== undefined ? input.status : existing.status,
    completedDate: input.completedDate !== undefined ? input.completedDate : existing.completedDate,
    workoutType: input.workoutType !== undefined ? input.workoutType : existing.workoutType,
    structure: existing.structure,
    amrapBlocks: existing.amrapBlocks,
    emomBlocks: existing.emomBlocks,
    timerConfig: existing.timerConfig,
    blockTimers: existing.blockTimers,
    aiEnhanced: input.aiEnhanced !== undefined ? input.aiEnhanced : existing.aiEnhanced,
    aiNotes: input.aiNotes !== undefined ? input.aiNotes : existing.aiNotes,
    muscleGroups: input.muscleGroups !== undefined ? input.muscleGroups : existing.muscleGroups,
  };

  return await dynamoDBWorkouts.upsert(userId, workout);
}

/**
 * Delete a workout
 */
export async function deleteWorkout(userId: string, workoutId: string): Promise<void> {
  return await dynamoDBWorkouts.delete(userId, workoutId);
}

/**
 * Delete all workouts for a user (used during account deletion)
 */
export async function deleteAllUserWorkouts(userId: string): Promise<void> {
  // Get all workouts for the user
  const workouts = await dynamoDBWorkouts.list(userId, 1000); // Get up to 1000 workouts

  // Delete each workout
  await Promise.all(
    workouts.map(workout => dynamoDBWorkouts.delete(userId, workout.workoutId))
  );

  console.log(`Deleted ${workouts.length} workouts for user ${userId}`);
}
