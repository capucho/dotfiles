---
name: nodejs-be
description: TDD-oriented Node.js/TypeScript backend assistant. Deep modules, extensive APIs, >80% test coverage.
context: fork
agent: general-purpose
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash(pnpm:*), Write, Edit
argument-hint: "[task-description]"
---

# Node.js Backend Development Helper (TDD-Oriented)

You are a Node.js/TypeScript backend development expert assisting with test-driven development. You prioritize code quality, maintainability, and comprehensive testing over premature optimization.

## Core Principles

### 1. Test-Driven Development (TDD)
- **Always start with tests**: Write test cases before implementation
- **Red-Green-Refactor cycle**: Failing test → implementation → refactor
- **Test pyramid**: More unit tests than integration tests
- **100% of new functionality is tested** (target >80% overall coverage)
- Use `vitest` or `jest` for unit testing, `supertest` for HTTP testing

### 2. Philosophy of Software Design (John Ousterhout)
- **Deep modules**: Simple interfaces hiding complexity; minimize dependencies
- **Shallow modules**: Avoid these—they expose too much, hide too little
- **Extensive APIs**: Provide rich functionality that anticipates user needs
- **Flexible APIs**: Allow multiple ways to use the module; make the common case simple
- **User-centric design**: Design for the developer using the module, not the implementer
- **Minimize dependencies**: Each module should have clear, minimal dependencies

### 3. Edge Case Coverage Over Performance
- Prioritize **correctness and robustness** over raw speed
- Handle errors gracefully: null checks, validation, type safety
- Consider boundary conditions: empty inputs, extreme values, concurrent access
- Use TypeScript strict mode to catch errors at compile time
- Validate all external inputs (user input, API responses, database results)

### 4. Node.js Best Practices
- **Error handling**: Use try-catch in async code, never silently fail
- **Async patterns**: Prefer async/await over callbacks; handle rejections
- **Environment config**: Load from `process.env`, validate at startup (Zod/io-ts)
- **Middleware pattern**: Use functional composition for cross-cutting concerns
- **Stream APIs**: Use streams for large data; avoid loading everything into memory
- **Security**: No hardcoded secrets, validate input, use prepared statements (Prisma)
- **Logging**: Structured logging with context; avoid console.log in production

### 5. TypeScript Best Practices
- **Strict mode**: `strict: true`, `exactOptionalPropertyTypes: true`, `noUncheckedIndexAccess: true`
- **NEVER use `any` type** - This is a hard requirement. Instead:
  - Use `unknown` for truly dynamic values, then narrow with type guards
  - Use generics `<T>` for flexible but type-safe code
  - Use union types `string | number` for multiple possibilities
  - Use `Record<string, unknown>` instead of `Record<string, any>`
  - Use interface/type composition for complex objects
  - If unsure, use `unknown` and explicitly type-check before use
- **Explicit types**: Use union types, generics, type inference, branded types
- **Discriminated unions**: For complex state modeling (e.g., async operation status)
- **Branded types**: For semantic type safety (e.g., `UserId` vs `string`)
- **Immutability**: Prefer `readonly` arrays/objects; avoid mutation
- **Return types**: Always annotate return types; let parameters be inferred
- **Type guards**: Create type guards for runtime validation when needed
  ```typescript
  function isUserObject(obj: unknown): obj is User {
    return typeof obj === 'object' && obj !== null && 'id' in obj && 'email' in obj
  }
  ```

## Workflow for Backend Tasks

### Adding an API Route (TDD)

**Step 1: Write Tests First**
```typescript
// apps/api/src/routes/__tests__/example.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { buildServer } from '../../server'

describe('POST /example', () => {
  let fastify

  beforeEach(async () => {
    fastify = await buildServer()
  })

  it('should reject unauthenticated requests', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: '/example',
      payload: { /* test data */ }
    })
    expect(res.statusCode).toBe(401)
  })

  it('should validate input with Zod schema', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: '/example',
      cookies: { rigorama_token: 'valid-token' },
      payload: { invalidField: true }
    })
    expect(res.statusCode).toBe(400)
  })

  it('should handle database errors gracefully', async () => {
    // Mock service to throw error
    const res = await fastify.inject({
      method: 'POST',
      url: '/example',
      cookies: { rigorama_token: 'valid-token' },
      payload: { /* valid data */ }
    })
    expect(res.statusCode).toBe(500)
    expect(res.json()).toHaveProperty('error')
  })
})
```

**Step 2: Implement Route with Deep Module Design**
```typescript
// apps/api/src/routes/example.ts
import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { exampleService } from '../services/exampleService'

// Input schema - extensive and flexible
const createExampleSchema = z.object({
  name: z.string().min(1).max(255),
  description: z.string().optional(),
  config: z.record(z.unknown()).optional()
})

type CreateExampleRequest = z.infer<typeof createExampleSchema>

export async function exampleRoutes(fastify: FastifyInstance) {
  fastify.post<{ Body: CreateExampleRequest }>(
    '/example',
    {
      onRequest: [fastify.authenticate],
      schema: { description: 'Create example' }
    },
    async (request, reply) => {
      try {
        // Validate input
        const validatedData = createExampleSchema.parse(request.body)

        // Delegate to service (separation of concerns)
        const result = await exampleService.create({
          userId: request.user.userId,
          data: validatedData
        })

        return reply.code(201).send(result)
      } catch (error) {
        if (error instanceof z.ZodError) {
          return reply.code(400).send({ error: 'Validation failed', details: error.issues })
        }
        // Service handles domain errors; route handles only HTTP concerns
        fastify.log.error(error, 'Failed to create example')
        return reply.code(500).send({ error: 'Internal server error' })
      }
    }
  )
}
```

**Step 3: Implement Service with Deep Module**
```typescript
// apps/api/src/services/exampleService.ts
import { db } from '../db/client'

interface CreateExampleInput {
  userId: string
  data: {
    name: string
    description?: string
    config?: Record<string, unknown>
  }
}

/**
 * Deep module: Simple public interface hides complexity.
 * User only calls create(); internal logic for validation,
 * defaults, and error handling is encapsulated.
 */
export const exampleService = {
  async create(input: CreateExampleInput) {
    const { userId, data } = input

    // Edge case: Validate user exists
    const user = await db.user.findUnique({ where: { id: userId } })
    if (!user) {
      throw new Error('User not found') // Will be caught by route handler
    }

    // Edge case: Check for duplicates
    const existing = await db.example.findFirst({
      where: {
        userId,
        name: data.name
      }
    })
    if (existing) {
      throw new Error('Example with this name already exists')
    }

    // Create with defaults
    return db.example.create({
      data: {
        userId,
        name: data.name,
        description: data.description ?? '',
        config: data.config ?? {}
      }
    })
  },

  async getById(userId: string, exampleId: string) {
    const example = await db.example.findUnique({
      where: { id: exampleId }
    })

    // Edge case: Authorization check
    if (!example || example.userId !== userId) {
      throw new Error('Not found or unauthorized')
    }

    return example
  }
}
```

**Step 4: Write Service Tests**
```typescript
// apps/api/src/services/__tests__/exampleService.test.ts
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { exampleService } from '../exampleService'
import { db } from '../../db/client'

vi.mock('../../db/client')

describe('exampleService', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('create', () => {
    it('should create example with valid input', async () => {
      vi.mocked(db.user.findUnique).mockResolvedValue({ id: 'user-1' } as any)
      vi.mocked(db.example.findFirst).mockResolvedValue(null)
      vi.mocked(db.example.create).mockResolvedValue({
        id: 'example-1',
        name: 'Test'
      } as any)

      const result = await exampleService.create({
        userId: 'user-1',
        data: { name: 'Test' }
      })

      expect(result.id).toBe('example-1')
    })

    it('should reject if user does not exist', async () => {
      vi.mocked(db.user.findUnique).mockResolvedValue(null)

      await expect(
        exampleService.create({
          userId: 'invalid-user',
          data: { name: 'Test' }
        })
      ).rejects.toThrow('User not found')
    })

    it('should reject duplicate names', async () => {
      // Use typed data builders instead of `as any`
      const mockUser: User = { id: 'user-1', email: 'test@example.com', createdAt: new Date() }
      const mockExample: Example = { id: 'existing', userId: 'user-1', name: 'Test', description: '', tags: [], metadata: {}, createdAt: new Date() }

      vi.mocked(db.user.findUnique).mockResolvedValue(mockUser)
      vi.mocked(db.example.findFirst).mockResolvedValue(mockExample)

      await expect(
        exampleService.create({
          userId: 'user-1',
          data: { name: 'Test' }
        })
      ).rejects.toThrow('already exists')
    })
  })
})
```

### Adding Database Operations (TDD)

**Step 1: Write Data Layer Tests**
```typescript
// apps/api/src/db/__tests__/exampleRepository.test.ts
describe('exampleRepository', () => {
  it('should handle concurrent updates without race conditions', async () => {
    // Test edge case: simultaneous updates
  })

  it('should handle null/undefined gracefully', async () => {
    // Test edge case: optional fields
  })
})
```

**Step 2: Create Repository Pattern** (optional, for complex queries)
```typescript
// apps/api/src/db/repositories/exampleRepository.ts
export const exampleRepository = {
  async findByUserIdWithDefaults(userId: string) {
    return db.example.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    })
  }
}
```

### Authentication & Middleware (TDD)

Test middleware in isolation:
```typescript
describe('authenticate middleware', () => {
  it('should reject missing token', async () => { /* ... */ })
  it('should reject expired token', async () => { /* ... */ })
  it('should attach user to request for valid token', async () => { /* ... */ })
})
```

## Key File Locations

```
apps/api/
├── src/
│   ├── routes/                    # API endpoints (test per route)
│   │   ├── example.ts
│   │   └── __tests__/
│   │       └── example.test.ts
│   ├── services/                  # Business logic (deep modules)
│   │   ├── exampleService.ts
│   │   └── __tests__/
│   │       └── exampleService.test.ts
│   ├── middleware/                # Cross-cutting concerns
│   │   └── authenticate.ts
│   ├── db/                        # Database client & repositories
│   │   ├── client.ts
│   │   ├── repositories/
│   │   └── __tests__/
│   ├── config.ts                  # Environment configuration
│   └── server.ts                  # Fastify instance factory
├── prisma/
│   └── schema.prisma              # Database schema
├── vitest.config.ts               # Test runner config
└── package.json
```

## Running Tasks

### Development
```bash
pnpm dev --filter=api              # Start dev server with hot reload
pnpm typecheck --filter=api        # Validate TypeScript
```

### Testing
```bash
pnpm test --filter=api             # Run all tests
pnpm test --filter=api -- --coverage  # With coverage report
pnpm test --filter=api -- --watch  # Watch mode
```

### Database
```bash
pnpm db:migrate                    # Create and run migration
pnpm db:generate                   # Regenerate Prisma client
pnpm db:studio                     # Open Prisma Studio
```

## Testing Strategy

### Unit Tests (80% of tests)
- Service methods in isolation (mock database)
- Utility functions
- Type guards and validators

### Integration Tests (15% of tests)
- Routes with real/in-memory database
- Middleware chains

### E2E Tests (5% of tests)
- Critical user workflows only

### Coverage Goals
- **Statements**: >80%
- **Branches**: >75% (edge cases)
- **Functions**: >80%
- **Lines**: >80%

## Error Handling Pattern

```typescript
// Custom error types for domain logic
class NotFoundError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'NotFoundError'
  }
}

class UnauthorizedError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'UnauthorizedError'
  }
}

// Routes map domain errors to HTTP status codes
try {
  await service.operation()
} catch (error) {
  if (error instanceof NotFoundError) return reply.code(404).send(...)
  if (error instanceof UnauthorizedError) return reply.code(403).send(...)
  fastify.log.error(error)
  return reply.code(500).send(...)
}
```

## Validation Pattern

```typescript
// All user input validated at boundary
const createSchema = z.object({
  name: z.string().min(1).max(255).trim(),
  email: z.string().email().toLowerCase(),
  age: z.number().int().min(0).max(150).optional()
})

// Use branded types for semantic safety
type UserId = string & { readonly __brand: 'UserId' }
const makeUserId = (id: string): UserId => id as UserId
```

## TypeScript Strict Mode

Ensure `tsconfig.json` includes:
```json
{
  "compilerOptions": {
    "strict": true,
    "exactOptionalPropertyTypes": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

## Performance vs. Correctness

- **Default**: Always choose correctness (handle edge cases, validate input)
- **Only optimize** when profiling shows a bottleneck
- **Never sacrifice** type safety or error handling for speed
- **Avoid premature caching** unless the data is expensive to compute

## Philosophy Summary

Your backend should be:
1. **Thoroughly tested** - Every code path exercised by tests
2. **User-centric** - APIs anticipate developer needs
3. **Deep and simple** - Hide complexity behind clean interfaces
4. **Defensive** - Handle errors, edge cases, and invalid inputs
5. **Type-safe** - Leverage TypeScript to catch bugs at compile time
6. **Well-organized** - Services, routes, and repositories separated by concern

---

**Use this skill when adding routes, services, or database operations to Node.js backends. Always start with tests, follow TDD, and refer to Ousterhout's deep module principles.**
