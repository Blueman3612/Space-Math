/**
 * Sample Custom API Route
 *
 * This route will be available at: https://<your-game-slug>.playcademy.gg/api/sample/custom
 */

import type { Context } from 'hono'

/**
 * GET /api/sample/custom
 *
 * Example of a basic custom API route
 */
export async function GET(c: Context): Promise<Response> {
    return c.json({
        success: true,
        message: 'Hello from your custom API route!',
        timestamp: new Date().toISOString(),
    })
}

/**
 * POST /api/sample/custom
 *
 * Example handling JSON request body
 */
export async function POST(c: Context): Promise<Response> {
    try {
        const body = await c.req.json()

        return c.json({
            success: true,
            message: 'Received your data',
            data: body,
        })
    } catch {
        return c.json(
            {
                success: false,
                error: 'Invalid JSON body',
            },
            400,
        )
    }
}

