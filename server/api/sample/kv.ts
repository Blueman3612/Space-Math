/**
 * Sample KV Storage API Route
 *
 * This route will be available at: https://<your-game-slug>.playcademy.gg/api/sample/kv
 */

import type { Context } from 'hono'

/**
 * Player state stored in KV
 */
interface PlayerState {
    /** Player's current score */
    score: number
    /** Current level */
    level: number
    /** Last played timestamp */
    lastPlayed: string
}

/**
 * GET /api/sample/kv
 *
 * Retrieve player state from KV storage
 */
export async function GET(c: Context): Promise<Response> {
    try {
        // Get user ID from query parameter
        const userId = c.req.query('userId') || 'demo-user'
        
        // Read from KV using user-specific key
        const stateJson = await c.env.KV.get(`user:${userId}:state`)
        
        if (!stateJson) {
            return c.json({
                success: true,
                data: null,
                message: 'No saved state found',
            })
        }

        const state = JSON.parse(stateJson) as PlayerState

        return c.json({
            success: true,
            data: state,
        })
    } catch (error) {
        return c.json(
            {
                success: false,
                error: 'Failed to fetch player state',
                details: error instanceof Error ? error.message : String(error),
            },
            500,
        )
    }
}

/**
 * POST /api/sample/kv
 *
 * Save player state to KV storage
 */
export async function POST(c: Context): Promise<Response> {
    try {
        const body = (await c.req.json()) as Partial<PlayerState> & { userId?: string }

        if (typeof body.score !== 'number' || body.score < 0) {
            return c.json(
                {
                    success: false,
                    error: 'Invalid score value',
                },
                400,
            )
        }

        const userId = body.userId || 'demo-user'

        // Prepare player state
        const state: PlayerState = {
            score: body.score,
            level: body.level ?? 1,
            lastPlayed: new Date().toISOString(),
        }

        // Write to KV using user-specific key
        await c.env.KV.put(`user:${userId}:state`, JSON.stringify(state))

        return c.json({
            success: true,
            data: state,
            message: 'Player state saved successfully',
        })
    } catch (error) {
        return c.json(
            {
                success: false,
                error: 'Failed to save player state',
                details: error instanceof Error ? error.message : String(error),
            },
            500,
        )
    }
}

/**
 * DELETE /api/sample/kv
 *
 * Clear player state from KV storage
 */
export async function DELETE(c: Context): Promise<Response> {
    try {
        const userId = c.req.query('userId') || 'demo-user'

        // Delete from KV
        await c.env.KV.delete(`user:${userId}:state`)

        return c.json({
            success: true,
            message: 'Player state cleared successfully',
        })
    } catch (error) {
        return c.json(
            {
                success: false,
                error: 'Failed to clear player state',
                details: error instanceof Error ? error.message : String(error),
            },
            500,
        )
    }
}

