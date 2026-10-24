/**
 * Template: API Route with Input Validation & Error Handling
 *
 * Key patterns:
 * - Zod schemas for input validation
 * - Separation of concerns (route → service)
 * - Comprehensive error handling
 * - Type safety with TypeScript
 */

import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import { z } from 'zod'
import { exampleService } from '../services/exampleService'

// ─── Input Validation Schemas ────────────────────────────────
// Make these extensive and flexible; support multiple use cases

const CreateExampleSchema = z.object({
  name: z.string().min(1).max(255).trim(),
  description: z.string().max(2000).optional(),
  tags: z.array(z.string()).optional().default([]),
  metadata: z.record(z.unknown()).optional()
})

const UpdateExampleSchema = CreateExampleSchema.partial().refine(
  (obj) => Object.keys(obj).length > 0,
  { message: 'At least one field must be provided' }
)

const QuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(10),
  search: z.string().optional()
})

type CreateExampleRequest = z.infer<typeof CreateExampleSchema>
type UpdateExampleRequest = z.infer<typeof UpdateExampleSchema>
type QueryParams = z.infer<typeof QuerySchema>

// ─── Route Handlers ──────────────────────────────────────────

export async function exampleRoutes(fastify: FastifyInstance) {
  /**
   * POST /example
   * Create a new example resource
   */
  fastify.post<{ Body: CreateExampleRequest }>(
    '/example',
    { onRequest: [fastify.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        // Validate input at boundary
        const validatedData = CreateExampleSchema.parse(request.body)

        // Delegate to service (keeps route thin)
        const result = await exampleService.create({
          userId: request.user.userId,
          data: validatedData
        })

        return reply.code(201).send(result)
      } catch (error) {
        return handleRouteError(error, reply, fastify)
      }
    }
  )

  /**
   * GET /example/:id
   * Retrieve a single example by ID
   */
  fastify.get<{ Params: { id: string } }>(
    '/example/:id',
    { onRequest: [fastify.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const result = await exampleService.getById(
          request.user.userId,
          request.params.id
        )

        if (!result) {
          return reply.code(404).send({ error: 'Not found' })
        }

        return reply.send(result)
      } catch (error) {
        return handleRouteError(error, reply, fastify)
      }
    }
  )

  /**
   * GET /example
   * List all examples with pagination and filtering
   */
  fastify.get<{ Querystring: QueryParams }>(
    '/example',
    { onRequest: [fastify.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const query = QuerySchema.parse(request.query)

        const result = await exampleService.list({
          userId: request.user.userId,
          pagination: {
            page: query.page,
            limit: query.limit
          },
          search: query.search
        })

        return reply.send(result)
      } catch (error) {
        return handleRouteError(error, reply, fastify)
      }
    }
  )

  /**
   * PUT /example/:id
   * Update an example (partial updates allowed)
   */
  fastify.put<{ Params: { id: string }; Body: UpdateExampleRequest }>(
    '/example/:id',
    { onRequest: [fastify.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const validatedData = UpdateExampleSchema.parse(request.body)

        const result = await exampleService.update({
          userId: request.user.userId,
          id: request.params.id,
          data: validatedData
        })

        return reply.send(result)
      } catch (error) {
        return handleRouteError(error, reply, fastify)
      }
    }
  )

  /**
   * DELETE /example/:id
   * Delete an example
   */
  fastify.delete<{ Params: { id: string } }>(
    '/example/:id',
    { onRequest: [fastify.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        await exampleService.delete(request.user.userId, request.params.id)

        return reply.code(204).send()
      } catch (error) {
        return handleRouteError(error, reply, fastify)
      }
    }
  )
}

// ─── Error Handling ──────────────────────────────────────────

type RouteError = Error & { code?: string; statusCode?: number }

function handleRouteError(
  error: unknown,
  reply: FastifyReply,
  fastify: FastifyInstance
): FastifyReply {
  // Validation errors
  if (error instanceof z.ZodError) {
    return reply.code(400).send({
      error: 'Validation failed',
      details: error.issues.map((issue) => ({
        field: issue.path.join('.'),
        message: issue.message
      }))
    })
  }

  // Domain-specific errors (custom error classes in service)
  const err = error as RouteError
  if (err.statusCode) {
    return reply.code(err.statusCode).send({ error: err.message })
  }

  // Unexpected errors
  fastify.log.error(error, 'Unhandled route error')
  return reply.code(500).send({
    error: 'Internal server error'
  })
}
