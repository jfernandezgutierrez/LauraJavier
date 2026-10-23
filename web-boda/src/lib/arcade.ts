export type GameKind = 'catch' | 'memory'
export const ROUND_MS = 1600
export const CATCH_ROUNDS = 12
export const MEMORY_ICONS = ['🦴', '🎾', '🐾', '🏠', '💛', '🥣']
export interface Challenge { id: string; kind: GameKind; board: number[] }
export interface GameReward { coins: number; xp: number; score: number }
export function catchScore(board: number[], moves: number[]) {
  return moves.reduce((score, lane, i) => score + (board[i] === lane ? 1 : 0), 0)
}
export function memoryStep(board: number[], matched: number[], a: number, b: number) {
  if (!Number.isInteger(a) || !Number.isInteger(b) || a < 0 || b < 0 || a >= board.length || b >= board.length || a === b || matched.includes(a) || matched.includes(b)) throw new Error('Pareja no válida')
  return board[a] === board[b] ? [...matched, a, b] : matched
}
