/**
 * Template: Comprehensive Unit Tests (TDD Approach)
 *
 * ⚠️  IMPORTANT: NEVER use `as any` or `any` type in tests or code
 * ⚠️  Instead: Use test data builders (see buildUser, buildExample below)
 *
 * Key patterns:
 * - Test behavior, not implementation details
 * - Arrange-Act-Assert structure
 * - Edge cases and error paths
 * - Mocking external dependencies (database)
 * - >80% coverage target
 * - Use data builders instead of type assertions
 */

import { describe, it, expect, beforeEach, vi } from 'vitest'
import {
  exampleService,
  NotFoundError,
  UnauthorizedError,
  ConflictError,
  ValidationError
} from '../exampleService'
import { db } from '../../db/client'

// Mock the database
vi.mock('../../db/client')

// ─── Test Data Builders ────────────────────────────────────
// Use builders instead of `as any` for type safety

type User = { id: string; email: string; createdAt: Date }
type Example = {
  id: string
  userId: string
  name: string
  description: string
  tags: string[]
  metadata: Record<string, unknown>
  createdAt: Date
}

const buildUser = (overrides?: Partial<User>): User => ({
  id: 'user-1',
  email: 'test@example.com',
  createdAt: new Date(),
  ...overrides
})

const buildExample = (overrides?: Partial<Example>): Example => ({
  id: 'example-1',
  userId: 'user-1',
  name: 'Test Example',
  description: 'A test example',
  tags: ['test'],
  metadata: { key: 'value' },
  createdAt: new Date(),
  ...overrides
})

describe('exampleService', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // ─── create() Tests ─────────────────────────────────────────

  describe('create', () => {
    it('should create an example with valid input', async () => {
      // Arrange
      const userId = 'user-1'
      const input = {
        name: 'Test Example',
        description: 'A test example',
        tags: ['test'],
        metadata: { key: 'value' }
      }

      const mockUser = buildUser({ id: userId })
      const mockExample = buildExample({ userId, ...input })

      vi.mocked(db.user.findUnique).mockResolvedValue(mockUser)
      vi.mocked(db.example.findFirst).mockResolvedValue(null)
      vi.mocked(db.example.create).mockResolvedValue(mockExample)

      // Act
      const result = await exampleService.create(userId, input)

      // Assert
      expect(result.id).toBe('example-1')
      expect(result.name).toBe('Test Example')
      expect(db.example.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId,
          name: input.name,
          tags: input.tags
        })
      })
    })

    it('should trim whitespace from name', async () => {
      // Arrange
      const userId = 'user-1'
      const input = { name: '  Test  ' }

      vi.mocked(db.user.findUnique).mockResolvedValue(buildUser({ id: userId }))
      vi.mocked(db.example.findFirst).mockResolvedValue(null)
      vi.mocked(db.example.create).mockResolvedValue(
        buildExample({ name: 'Test' })
      )

      // Act
      await exampleService.create(userId, input)

      // Assert
      expect(db.example.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          name: 'Test'
        })
      })
    })

    it('should provide default values for optional fields', async () => {
      // Arrange
      const userId = 'user-1'
      const input = { name: 'Test' }

      vi.mocked(db.user.findUnique).mockResolvedValue(buildUser({ id: userId }))
      vi.mocked(db.example.findFirst).mockResolvedValue(null)
      vi.mocked(db.example.create).mockResolvedValue(
        buildExample({
          description: '',
          tags: [],
          metadata: {}
        })
      )

      // Act
      await exampleService.create(userId, input)

      // Assert
      expect(db.example.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          description: '',
          tags: [],
          metadata: {}
        })
      })
    })

    // ─── Edge Cases & Error Paths ───────────────────────────

    it('should reject if user does not exist', async () => {
      // Arrange
      vi.mocked(db.user.findUnique).mockResolvedValue(null)

      // Act & Assert
      await expect(
        exampleService.create('invalid-user', { name: 'Test' })
      ).rejects.toThrow(NotFoundError)
    })

    it('should reject if example with same name already exists', async () => {
      // Arrange
      const userId = 'user-1'
      vi.mocked(db.user.findUnique).mockResolvedValue({ id: userId } as any)
      vi.mocked(db.example.findFirst).mockResolvedValue({
        id: 'existing'
      } as any)

      // Act & Assert
      await expect(
        exampleService.create(userId, { name: 'Test' })
      ).rejects.toThrow(ConflictError)
    })

    it('should handle case-insensitive duplicate check', async () => {
      // Arrange
      const userId = 'user-1'
      vi.mocked(db.user.findUnique).mockResolvedValue({ id: userId } as any)
      vi.mocked(db.example.findFirst).mockResolvedValue({
        id: 'existing'
      } as any)

      // Act & Assert
      await expect(
        exampleService.create(userId, { name: 'test' }) // lowercase
      ).rejects.toThrow(ConflictError)

      // Verify case-insensitive query was made
      expect(db.example.findFirst).toHaveBeenCalledWith({
        where: expect.objectContaining({
          name: expect.objectContaining({
            equals: 'test',
            mode: 'insensitive'
          })
        })
      })
    })

    it('should reject empty names', async () => {
      // Arrange
      const userId = 'user-1'
      vi.mocked(db.user.findUnique).mockResolvedValue({ id: userId } as any)

      // Act & Assert
      await expect(
        exampleService.create(userId, { name: '   ' })
      ).rejects.toThrow(ValidationError)
    })

    it('should reject if tags exceed max count', async () => {
      // Arrange
      const userId = 'user-1'
      const tooManyTags = Array(101).fill('tag')

      vi.mocked(db.user.findUnique).mockResolvedValue({ id: userId } as any)

      // Act & Assert
      await expect(
        exampleService.create(userId, {
          name: 'Test',
          tags: tooManyTags
        })
      ).rejects.toThrow(ValidationError)
    })

    it('should handle database constraint violations', async () => {
      // Arrange
      const userId = 'user-1'
      vi.mocked(db.user.findUnique).mockResolvedValue({ id: userId } as any)
      vi.mocked(db.example.findFirst).mockResolvedValue(null)
      vi.mocked(db.example.create).mockRejectedValue(
        new Error('Unique constraint failed')
      )

      // Act & Assert
      await expect(
        exampleService.create(userId, { name: 'Test' })
      ).rejects.toThrow(ConflictError)
    })
  })

  // ─── getById() Tests ────────────────────────────────────────

  describe('getById', () => {
    it('should retrieve example by ID', async () => {
      // Arrange
      const userId = 'user-1'
      const exampleId = 'example-1'

      vi.mocked(db.example.findUnique).mockResolvedValue(
        buildExample({ id: exampleId, userId, name: 'Test' })
      )

      // Act
      const result = await exampleService.getById(userId, exampleId)

      // Assert
      expect(result.id).toBe(exampleId)
      expect(db.example.findUnique).toHaveBeenCalledWith({
        where: { id: exampleId }
      })
    })

    it('should throw NotFoundError if example does not exist', async () => {
      // Arrange
      vi.mocked(db.example.findUnique).mockResolvedValue(null)

      // Act & Assert
      await expect(
        exampleService.getById('user-1', 'invalid-id')
      ).rejects.toThrow(NotFoundError)
    })

    it('should throw UnauthorizedError if user does not own example', async () => {
      // Arrange
      vi.mocked(db.example.findUnique).mockResolvedValue(
        buildExample({ id: 'example-1', userId: 'different-user' })
      )

      // Act & Assert
      await expect(
        exampleService.getById('user-1', 'example-1')
      ).rejects.toThrow(UnauthorizedError)
    })

    it('should reject invalid example IDs', async () => {
      // Arrange & Act & Assert
      await expect(
        exampleService.getById('user-1', '')
      ).rejects.toThrow(ValidationError)

      await expect(
        exampleService.getById('user-1', '   ')
      ).rejects.toThrow(ValidationError)
    })
  })

  // ─── list() Tests ──────────────────────────────────────────

  describe('list', () => {
    it('should list examples with pagination', async () => {
      // Arrange
      const userId = 'user-1'
      const items: Example[] = [
        buildExample({ id: '1', name: 'Example 1' }),
        buildExample({ id: '2', name: 'Example 2' })
      ]

      vi.mocked(db.example.count).mockResolvedValue(2)
      vi.mocked(db.example.findMany).mockResolvedValue(items)

      // Act
      const result = await exampleService.list({
        userId,
        pagination: { page: 1, limit: 10 }
      })

      // Assert
      expect(result.items).toEqual(items)
      expect(result.pagination.total).toBe(2)
      expect(result.pagination.totalPages).toBe(1)
      expect(result.pagination.hasMore).toBe(false)
    })

    it('should enforce pagination limits', async () => {
      // Arrange
      vi.mocked(db.example.count).mockResolvedValue(0)
      vi.mocked(db.example.findMany).mockResolvedValue([])

      // Act
      await exampleService.list({
        userId: 'user-1',
        pagination: { page: 0, limit: 1000 }
      })

      // Assert - page should be clamped to 1, limit to 100
      expect(db.example.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 0,
          take: 100
        })
      )
    })

    it('should search by name and description', async () => {
      // Arrange
      vi.mocked(db.example.count).mockResolvedValue(1)
      vi.mocked(db.example.findMany).mockResolvedValue([])

      // Act
      await exampleService.list({
        userId: 'user-1',
        pagination: { page: 1, limit: 10 },
        search: 'test'
      })

      // Assert
      expect(db.example.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            OR: expect.arrayContaining([
              expect.objectContaining({
                name: expect.objectContaining({
                  contains: 'test',
                  mode: 'insensitive'
                })
              })
            ])
          })
        })
      )
    })

    it('should ignore empty search queries', async () => {
      // Arrange
      vi.mocked(db.example.count).mockResolvedValue(0)
      vi.mocked(db.example.findMany).mockResolvedValue([])

      // Act
      await exampleService.list({
        userId: 'user-1',
        pagination: { page: 1, limit: 10 },
        search: '   '
      })

      // Assert - search filter should not be applied
      expect(db.example.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            userId: 'user-1'
            // No OR clause
          })
        })
      )
    })
  })

  // ─── update() Tests ────────────────────────────────────────

  describe('update', () => {
    it('should update example with partial data', async () => {
      // Arrange
      const userId = 'user-1'
      const exampleId = 'example-1'

      vi.mocked(db.example.findUnique).mockResolvedValue(
        buildExample({ id: exampleId, userId, name: 'Original' })
      )

      vi.mocked(db.example.findFirst).mockResolvedValue(null) // No duplicates
      vi.mocked(db.example.update).mockResolvedValue(
        buildExample({ id: exampleId, name: 'Updated' })
      )

      // Act
      const result = await exampleService.update(userId, exampleId, {
        name: 'Updated'
      })

      // Assert
      expect(result.name).toBe('Updated')
      expect(db.example.update).toHaveBeenCalledWith({
        where: { id: exampleId },
        data: expect.objectContaining({
          name: 'Updated'
        })
      })
    })

    it('should not include undefined fields in update', async () => {
      // Arrange
      const userId = 'user-1'
      const exampleId = 'example-1'

      vi.mocked(db.example.findUnique).mockResolvedValue(
        buildExample({ id: exampleId, userId })
      )

      vi.mocked(db.example.update).mockResolvedValue(buildExample())

      // Act
      await exampleService.update(userId, exampleId, {
        name: 'Updated',
        description: undefined
      })

      // Assert
      expect(db.example.update).toHaveBeenCalledWith({
        where: { id: exampleId },
        data: expect.not.objectContaining({
          description: undefined
        })
      })
    })

    it('should prevent duplicate names on update', async () => {
      // Arrange
      const userId = 'user-1'
      const exampleId = 'example-1'

      vi.mocked(db.example.findUnique)
        .mockResolvedValueOnce(buildExample({ id: exampleId, userId, name: 'Original' })) // getById call
        .mockResolvedValueOnce(null) // after auth check

      vi.mocked(db.example.findFirst).mockResolvedValue(
        buildExample({ id: 'other-id' })
      )

      // Act & Assert
      await expect(
        exampleService.update(userId, exampleId, { name: 'Duplicate' })
      ).rejects.toThrow(ConflictError)
    })

    it('should throw if example not found on update', async () => {
      // Arrange
      vi.mocked(db.example.findUnique).mockResolvedValue(null)

      // Act & Assert
      await expect(
        exampleService.update('user-1', 'invalid-id', { name: 'Test' })
      ).rejects.toThrow(NotFoundError)
    })
  })

  // ─── delete() Tests ────────────────────────────────────────

  describe('delete', () => {
    it('should delete an example', async () => {
      // Arrange
      const userId = 'user-1'
      const exampleId = 'example-1'

      vi.mocked(db.example.findUnique).mockResolvedValue(
        buildExample({ id: exampleId, userId })
      )

      vi.mocked(db.example.delete).mockResolvedValue(buildExample())

      // Act
      await exampleService.delete(userId, exampleId)

      // Assert
      expect(db.example.delete).toHaveBeenCalledWith({
        where: { id: exampleId }
      })
    })

    it('should verify ownership before deletion', async () => {
      // Arrange
      vi.mocked(db.example.findUnique).mockResolvedValue(
        buildExample({ id: 'example-1', userId: 'different-user' })
      )

      // Act & Assert
      await expect(
        exampleService.delete('user-1', 'example-1')
      ).rejects.toThrow(UnauthorizedError)
    })
  })
})

/**
 * Coverage: This test file should achieve >80% line and branch coverage.
 * Run with: pnpm test --filter=api -- --coverage
 *
 * Missing coverage indicates:
 * - Untested error paths (add more error scenario tests)
 * - Untested branches in conditionals (test both true/false paths)
 * - Untested edge cases (add tests for boundary conditions)
 */
