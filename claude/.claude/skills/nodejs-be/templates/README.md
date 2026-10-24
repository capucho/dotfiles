# Backend Development Templates

This directory contains reference templates for TDD-oriented Node.js/TypeScript backend development following the Philosophy of Software Design principles.

## Files

### `route-template.ts`
Complete example of an API route with:
- **Input validation** using Zod schemas
- **Comprehensive CRUD operations** (Create, Read, Update, Delete, List)
- **Extensive and flexible API** supporting multiple query patterns
- **Error handling** mapping domain errors to HTTP status codes
- **Type safety** with TypeScript

**Key patterns:**
- Route handlers delegate to services (separation of concerns)
- Schemas are extensive and flexible (anticipate user needs)
- All errors handled with appropriate HTTP status codes
- Authentication enforced via middleware

### `service-template.ts`
Deep module implementation with:
- **Simple public interface** hiding internal complexity
- **Extensive business logic** (CRUD + batch operations)
- **Custom error types** for domain-specific failures
- **Edge case handling** (duplicates, authorization, validation)
- **Batch operations** showing API extensibility

**Key patterns:**
- All public methods have clear contracts (inputs/outputs)
- Error handling with semantic error types
- Edge case validation (empty inputs, bounds checking, authorization)
- Reusable internal helper functions (not exposed)

### `test-template.ts`
Comprehensive unit tests following TDD with:
- **Arrange-Act-Assert structure** for clarity
- **Edge case and error path coverage** (>80% target)
- **Mocked dependencies** (database calls)
- **Behavior-focused tests** (not implementation details)
- **Coverage analysis** guidance

**Key patterns:**
- Test one behavior per test
- Clear test names describing expected behavior
- Both happy path and error cases
- Mocking external dependencies (db, APIs, etc.)

## How to Use These Templates

### 1. Creating a New Feature

Use these steps in order:

```bash
# 1. Create test file first (TDD)
cp templates/test-template.ts apps/api/src/services/__tests__/myFeature.test.ts
# Edit to test your business logic

# 2. Create service implementation
cp templates/service-template.ts apps/api/src/services/myFeatureService.ts
# Implement to pass tests

# 3. Create route handler
cp templates/route-template.ts apps/api/src/routes/myFeature.ts
# Implement routes using your service
```

### 2. Following TDD Cycle

```bash
# Run tests (they fail - RED)
pnpm test --filter=api -- myFeature.test.ts

# Implement code to make tests pass (GREEN)
# Edit service and route files

# Refactor to improve code quality (REFACTOR)
pnpm typecheck --filter=api

# Verify coverage
pnpm test --filter=api -- --coverage
```

### 3. Coverage Requirements

After implementation, verify coverage meets standards:

```bash
pnpm test --filter=api -- --coverage

# Expected results:
# - Statements: >80%
# - Branches: >75%
# - Functions: >80%
# - Lines: >80%

# If coverage is low:
# - Run coverage report in HTML: pnpm test --filter=api -- --coverage
# - Check which lines/branches are uncovered
# - Add tests for error cases and edge conditions
```

## Philosophy of Software Design Principles Applied

### Deep Modules

**Example from service template:**
```typescript
export const exampleService = {
  async create(userId: string, input: CreateInput) {
    // Complex internal logic hidden here:
    // - User existence checks
    // - Duplicate detection
    // - Default value assignment
    // - Error handling

    // Public interface is simple!
  }
}
```

The user of this service calls `create()` once, and all the complexity is hidden inside.

### Extensive, Flexible APIs

**Example from route template:**
```typescript
// Supports all these use cases:
POST   /example                          // Create
GET    /example                          // List with pagination & search
GET    /example/:id                      // Get single
PUT    /example/:id                      // Update (partial)
DELETE /example/:id                      // Delete
```

The API anticipates different user needs without requiring additional endpoints.

### User-Centric Design

Templates are designed around **how developers will use them**:
- Routes take simple middleware for auth (not configuration objects)
- Services return clear data types (not raw database objects)
- Errors are semantic (`NotFoundError`, `UnauthorizedError`) not generic
- Search and pagination just work without complex query languages

### Edge Case Coverage

Every template includes tests and handling for:
- **Null/undefined inputs** - validation at boundaries
- **Duplicate detection** - preventing data corruption
- **Authorization checks** - preventing unauthorized access
- **Empty results** - graceful handling
- **Database errors** - semantic error transformation

## Example: Building a New Feature

### Feature: "Add a guitar effects library to pedalboards"

**Step 1: Write failing tests**
```typescript
// effects-library.test.ts
describe('effectsLibraryService', () => {
  it('should create a new effects library', async () => {
    const result = await effectsLibraryService.create(
      'user-1',
      { name: 'My Effects' }
    )
    expect(result.id).toBeDefined()
  })

  it('should prevent duplicate library names', async () => {
    // ... test that duplicates are rejected
  })
})
```

**Step 2: Implement service**
```typescript
// effects-library-service.ts
export const effectsLibraryService = {
  async create(userId: string, input: CreateInput) {
    // Validate user exists
    // Check for duplicates
    // Create library
    // Return result
  }
}
```

**Step 3: Implement routes**
```typescript
// effects-library-routes.ts
export async function effectsLibraryRoutes(fastify: FastifyInstance) {
  fastify.post('/effects-library',
    { onRequest: [fastify.authenticate] },
    async (request, reply) => {
      const data = CreateLibrarySchema.parse(request.body)
      const result = await effectsLibraryService.create(
        request.user.userId,
        data
      )
      return reply.code(201).send(result)
    }
  )
}
```

**Step 4: Verify coverage**
```bash
pnpm test --filter=api -- --coverage

# Aim for >80% coverage
# If coverage is low, add tests for uncovered branches
```

## Avoiding the `any` Type (Critical Rule)

**Never use `any` type.** Instead, use these approaches:

### 1. Use `unknown` for Dynamic Values
```typescript
// ❌ BAD - using any
function process(data: any) {
  return data.name
}

// ✅ GOOD - using unknown with type guards
function process(data: unknown): string {
  if (typeof data === 'object' && data !== null && 'name' in data) {
    return (data as { name: string }).name
  }
  throw new Error('Invalid data')
}
```

### 2. Use Generics for Flexible APIs
```typescript
// ❌ BAD - any hides the type
function wrap(value: any): { value: any } {
  return { value }
}

// ✅ GOOD - generics preserve type
function wrap<T>(value: T): { value: T } {
  return { value }
}
```

### 3. Use Union Types for Multiple Possibilities
```typescript
// ❌ BAD - any
function handle(input: any): void { }

// ✅ GOOD - union types
function handle(input: string | number | boolean): void { }
```

### 4. Use Discriminated Unions for Complex Types
```typescript
// ✅ GOOD - discriminated union
type Result =
  | { status: 'success'; data: string }
  | { status: 'error'; error: Error }

function process(result: Result) {
  if (result.status === 'success') {
    console.log(result.data) // Type safe
  } else {
    console.error(result.error)
  }
}
```

### 5. Use Data Builders for Tests
```typescript
// ❌ BAD - using as any
const mockUser = { id: 'user-1' } as any

// ✅ GOOD - using typed builders
const buildUser = (overrides?: Partial<User>): User => ({
  id: 'user-1',
  email: 'test@example.com',
  ...overrides
})
const mockUser = buildUser()
```

## Common Patterns

### Error Handling Pattern
```typescript
// 1. Define semantic error types
export class NotFoundError extends Error {
  statusCode = 404
  // ...
}

// 2. Use in service
throw new NotFoundError('Resource not found')

// 3. Handle in route
catch (error) {
  if (error instanceof NotFoundError) {
    return reply.code(error.statusCode).send({ error: error.message })
  }
}
```

### Validation Pattern
```typescript
// 1. Define Zod schema
const CreateSchema = z.object({
  name: z.string().min(1).max(255)
})

// 2. Validate at boundary (route)
const data = CreateSchema.parse(request.body)

// 3. Pass validated data to service
await service.create(data)
```

### Testing Async Operations
```typescript
// Always use async/await syntax
describe('async operation', () => {
  it('should handle success', async () => {
    const result = await service.operation()
    expect(result).toBeDefined()
  })

  it('should handle errors', async () => {
    await expect(service.operation()).rejects.toThrow(Error)
  })
})
```

## Best Practices Summary

✅ **Do:**
- Start with tests (TDD)
- Keep modules deep (simple interface, complex internals)
- Handle edge cases in services
- Use semantic error types
- Validate all inputs at boundaries
- Aim for >80% test coverage
- Use TypeScript strict mode
- Make APIs extensive and flexible
- Use data builders for test mocks (see `buildUser()`, `buildExample()`)

❌ **Don't:**
- Implement features without tests
- Let errors propagate silently
- Expose internal implementation details
- Create shallow modules (many simple methods)
- Rely on caller to handle edge cases
- Skip input validation
- Use generic error messages
- **NEVER use `any` type** (use `unknown` with type guards, generics, or unions instead)
- Use `as any` type assertions in tests (use data builders instead)

## References

- **Philosophy of Software Design** by John Ousterhout
- **Test-Driven Development** by Kent Beck
- **Vitest Documentation** - Testing framework
- **Zod Documentation** - Runtime type validation
- **Fastify Documentation** - Web framework
- **Prisma Documentation** - ORM

---

For more details, refer to the main `SKILL.md` in the parent directory.
