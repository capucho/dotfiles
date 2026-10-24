/**
 * Template: Service Layer (Deep Module Pattern)
 *
 * Key patterns:
 * - Deep module: simple public API, hidden complexity
 * - Extensive, flexible interface (anticipates user needs)
 * - Comprehensive error handling
 * - Edge case coverage
 * - Business logic isolated from HTTP concerns
 */

import { db } from '../db/client'

// ─── Custom Error Types ──────────────────────────────────────
// Domain-specific errors that routes can map to HTTP status codes

export class NotFoundError extends Error {
  statusCode = 404
  constructor(message: string) {
    super(message)
    this.name = 'NotFoundError'
  }
}

export class UnauthorizedError extends Error {
  statusCode = 403
  constructor(message: string) {
    super(message)
    this.name = 'UnauthorizedError'
  }
}

export class ConflictError extends Error {
  statusCode = 409
  constructor(message: string) {
    super(message)
    this.name = 'ConflictError'
  }
}

export class ValidationError extends Error {
  statusCode = 400
  constructor(message: string) {
    super(message)
    this.name = 'ValidationError'
  }
}

// ─── Types ──────────────────────────────────────────────────

interface CreateInput {
  name: string
  description?: string
  tags?: string[]
  metadata?: Record<string, unknown>
}

interface UpdateInput {
  name?: string
  description?: string
  tags?: string[]
  metadata?: Record<string, unknown>
}

interface PaginationParams {
  page: number
  limit: number
}

interface ListOptions {
  userId: string
  pagination: PaginationParams
  search?: string
}

// ─── Deep Module: exampleService ────────────────────────────

/**
 * Simple, extensive public interface hides all complexity.
 * Users interact with this object; implementation details are encapsulated.
 */
export const exampleService = {
  /**
   * Create a new example
   *
   * Edge cases handled:
   * - User existence validation
   * - Duplicate name detection
   * - Metadata validation
   * - Database error handling
   */
  async create(
    userId: string,
    input: CreateInput
  ): Promise<{
    id: string
    name: string
    description: string
    tags: string[]
    metadata: Record<string, unknown>
    createdAt: Date
  }> {
    // Edge case: Validate user exists
    const user = await db.user.findUnique({ where: { id: userId } })
    if (!user) {
      throw new NotFoundError('User not found')
    }

    // Edge case: Check for duplicate name (case-insensitive)
    const existing = await db.example.findFirst({
      where: {
        userId,
        name: {
          equals: input.name,
          mode: 'insensitive'
        }
      }
    })
    if (existing) {
      throw new ConflictError(
        `Example with name "${input.name}" already exists`
      )
    }

    // Edge case: Validate input
    if (!input.name || input.name.trim().length === 0) {
      throw new ValidationError('Name cannot be empty')
    }

    if (input.tags && input.tags.length > 100) {
      throw new ValidationError('Maximum 100 tags allowed')
    }

    // Create with defaults
    try {
      return await db.example.create({
        data: {
          userId,
          name: input.name.trim(),
          description: input.description ?? '',
          tags: input.tags ?? [],
          metadata: input.metadata ?? {}
        }
      })
    } catch (error) {
      // Database constraint violations
      if (error instanceof Error && error.message.includes('Unique constraint')) {
        throw new ConflictError('This resource already exists')
      }
      throw error
    }
  },

  /**
   * Get example by ID with authorization
   *
   * Edge cases:
   * - Example doesn't exist
   * - User doesn't have access
   * - Null/undefined handling
   */
  async getById(userId: string, exampleId: string) {
    // Edge case: Validate input
    if (!exampleId || exampleId.trim().length === 0) {
      throw new ValidationError('Invalid example ID')
    }

    const example = await db.example.findUnique({
      where: { id: exampleId }
    })

    // Edge case: Authorization check
    if (!example) {
      throw new NotFoundError('Example not found')
    }

    if (example.userId !== userId) {
      throw new UnauthorizedError('You do not have access to this example')
    }

    return example
  },

  /**
   * List examples with pagination and search
   *
   * Edge cases:
   * - Page out of bounds
   * - Invalid search query
   * - Empty results
   */
  async list(options: ListOptions) {
    const { userId, pagination, search } = options

    // Edge case: Validate pagination
    const page = Math.max(1, pagination.page)
    const limit = Math.min(100, Math.max(1, pagination.limit))

    // Build search filter
    const searchFilter =
      search && search.trim().length > 0
        ? {
            OR: [
              {
                name: {
                  contains: search.trim(),
                  mode: 'insensitive' as const
                }
              },
              {
                description: {
                  contains: search.trim(),
                  mode: 'insensitive' as const
                }
              }
            ]
          }
        : {}

    // Get total count (for pagination info)
    const total = await db.example.count({
      where: {
        userId,
        ...searchFilter
      }
    })

    // Get paginated results
    const items = await db.example.findMany({
      where: {
        userId,
        ...searchFilter
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit
    })

    return {
      items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasMore: page < Math.ceil(total / limit)
      }
    }
  },

  /**
   * Update an example (partial updates)
   *
   * Edge cases:
   * - Empty update (no fields provided)
   * - Authorization check
   * - Duplicate name after update
   */
  async update(
    userId: string,
    exampleId: string,
    input: UpdateInput
  ) {
    // Edge case: Validate example exists and user has access
    const existing = await exampleService.getById(userId, exampleId)
    if (!existing) {
      throw new NotFoundError('Example not found')
    }

    // Edge case: Check for duplicate name if updating name
    if (input.name && input.name !== existing.name) {
      const duplicate = await db.example.findFirst({
        where: {
          userId,
          name: {
            equals: input.name.trim(),
            mode: 'insensitive'
          },
          id: { not: exampleId }
        }
      })
      if (duplicate) {
        throw new ConflictError(
          `Example with name "${input.name}" already exists`
        )
      }
    }

    // Update only provided fields
    const updateData: Partial<UpdateInput> = {}
    if (input.name !== undefined) updateData.name = input.name.trim()
    if (input.description !== undefined) updateData.description = input.description
    if (input.tags !== undefined) updateData.tags = input.tags
    if (input.metadata !== undefined) updateData.metadata = input.metadata

    try {
      return await db.example.update({
        where: { id: exampleId },
        data: updateData
      })
    } catch (error) {
      if (error instanceof Error && error.message.includes('not found')) {
        throw new NotFoundError('Example not found')
      }
      throw error
    }
  },

  /**
   * Delete an example
   *
   * Edge cases:
   * - Authorization check
   * - Cascade deletes (related data)
   */
  async delete(userId: string, exampleId: string): Promise<void> {
    // Edge case: Verify ownership before delete
    const existing = await exampleService.getById(userId, exampleId)
    if (!existing) {
      throw new NotFoundError('Example not found')
    }

    try {
      await db.example.delete({
        where: { id: exampleId }
      })
    } catch (error) {
      if (error instanceof Error && error.message.includes('not found')) {
        throw new NotFoundError('Example not found')
      }
      throw error
    }
  },

  /**
   * Batch operations for bulk updates
   * Demonstrates extensibility for advanced use cases
   */
  async batchUpdate(
    userId: string,
    updates: Array<{ id: string; data: UpdateInput }>
  ) {
    const results = []

    for (const update of updates) {
      try {
        const result = await exampleService.update(
          userId,
          update.id,
          update.data
        )
        results.push({ id: update.id, success: true, data: result })
      } catch (error) {
        results.push({
          id: update.id,
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        })
      }
    }

    return results
  }
}
