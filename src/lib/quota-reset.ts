export function getMonthKey(date: Date = new Date()): string {
  return date.toISOString().slice(0, 7); // YYYY-MM
}

export function isWeeklyResetDue(lastReset?: string | null, now: Date = new Date()): boolean {
  if (!lastReset) return true;
  const last = new Date(lastReset);
  if (Number.isNaN(last.getTime())) return true;
  const diffMs = now.getTime() - last.getTime();
  return diffMs >= 7 * 24 * 60 * 60 * 1000;
}

export function isMonthlyResetDue(lastReset?: string | null, now: Date = new Date()): boolean {
  if (!lastReset) return true;
  const last = new Date(lastReset);
  if (Number.isNaN(last.getTime())) return true;
  return last.getUTCFullYear() !== now.getUTCFullYear() || last.getUTCMonth() !== now.getUTCMonth();
}
