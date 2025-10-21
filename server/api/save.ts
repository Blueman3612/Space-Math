/**
 * Save Data KV Storage API Route
 *
 * This route will be available at: https://<your-game-slug>.playcademy.gg/api/save
 *
 * Handles all player save data storage using KV storage
 */

import { verifyGameToken } from '@playcademy/sdk/server'

/**
 * Complete save data structure
 */
interface SaveData {
    version: string
    save_structure: string
    packs: Record<string, any>
    questions: Record<string, any[]>
    sfx_volume: number
    music_volume: number
    drill_mode?: {
        high_score: number
    }
}

const userNotAuthenticatedResponse = (c: Context) =>
    c.json(
        {
            success: false,
            error: 'User not authenticated',
        },
        401,
    )

const getUserId = async (c: Context) => {
    const authToken = c.req.header('Authorization')?.split(' ')[1]

    if (!authToken) {
        return userNotAuthenticatedResponse(c)
    }

    const { user } = await verifyGameToken(authToken)

    if (!user) {
        return userNotAuthenticatedResponse(c)
    }

    return user.sub
}

/**
 * GET /api/save
 *
 * Retrieve player save data from KV storage
 */
export async function GET(c: Context): Promise<Response> {
    try {
        console.log(c.env)
        console.log('GET /api/save')
        const userId = await getUserId(c)

        // Read from KV using user-specific key
        const key = `user:${userId}:savedata`
        console.log(`[Save API GET] Reading key: ${key}`)
        const saveDataJson = await c.env.KV.get(key)

        console.log(
            `[Save API GET] Retrieved data length: ${saveDataJson?.length || 0}`,
        )

        if (!saveDataJson) {
            return c.json({
                success: true,
                data: null,
                message: 'No saved data found',
            })
        }

        const saveData = JSON.parse(saveDataJson) as SaveData

        return c.json({
            success: true,
            data: saveData,
        })
    } catch (error) {
        console.error('Failed to fetch save data:', error)
        return c.json(
            {
                success: false,
                error: 'Failed to fetch save data',
                details: error instanceof Error ? error.message : String(error),
            },
            500,
        )
    }
}

/**
 * POST /api/save
 *
 * Save player data to KV storage
 */
export async function POST(c: Context): Promise<Response> {
    try {
        const userId = await getUserId(c)

        const saveData = (await c.req.json()) as SaveData

        // Validate basic structure
        if (!saveData.version || !saveData.save_structure) {
            return c.json(
                {
                    success: false,
                    error: 'Invalid save data structure',
                },
                400,
            )
        }

        // Write to KV using user-specific key
        const key = `user:${userId}:savedata`
        const dataString = JSON.stringify(saveData)
        console.log(
            `[Save API POST] Saving key: ${key}, data length: ${dataString.length}`,
        )
        await c.env.KV.put(key, dataString)
        console.log(`[Save API POST] Save successful`)

        return c.json({
            success: true,
            message: 'Save data stored successfully',
        })
    } catch (error) {
        console.error('Failed to save data:', error)
        return c.json(
            {
                success: false,
                error: 'Failed to save data',
                details: error instanceof Error ? error.message : String(error),
            },
            500,
        )
    }
}

/**
 * DELETE /api/save
 *
 * Clear player save data from KV storage (reset progress)
 */
export async function DELETE(c: Context): Promise<Response> {
    try {
        const userId = await getUserId(c)

        // Delete from KV
        await c.env.KV.delete(`user:${userId}:savedata`)

        return c.json({
            success: true,
            message: 'Save data cleared successfully',
        })
    } catch (error) {
        console.error('Failed to clear save data:', error)
        return c.json(
            {
                success: false,
                error: 'Failed to clear save data',
                details: error instanceof Error ? error.message : String(error),
            },
            500,
        )
    }
}
