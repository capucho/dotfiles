---
name: ddd
description: DDD coding practices and patterns for implementation. Load when discussing how to structure code around bounded contexts, evaluating technical trade-offs, or implementing DDD patterns.
---

# DDD Coding Practices

## Code structure

Organize by bounded context, not technical layer:

- **Domain**: entities, aggregates, value objects, business rules — no framework dependencies
- **Application**: orchestration, use cases, command/query handlers
- **Adapters**: repositories, API clients, message publishers — behind interfaces
- **Domain events**: cross-context communication; publish when significant business things happen

Isolate core business logic from infrastructure via dependency injection and interfaces.

## Core patterns

- **Aggregates**: consistency boundary — one transaction per aggregate; enforce invariants inside
- **Value objects**: immutable, compared by value (Money, Email, Address) — not primitives
- **Repositories**: domain-oriented interfaces, not generic CRUD; persistence is an adapter concern
- **Domain events**: decouple contexts; publish on meaningful state transitions
- **Anti-corruption layer**: translate external models at boundaries — never let external concepts leak in

## Pitfalls

- **Leaky abstractions**: domain logic depending on a framework? That kills testability
- **Boundary violations**: feature touching multiple contexts? Define the communication pattern first
- **Anemic models**: aggregate is just a data bag? Business logic belongs on it, not in services
- **Generic naming**: "Order", "User", "Item" mean nothing — what does this domain call them?
- **God aggregates**: doing too much? Split it; aggregates should be small and focused
- **Adapter complexity**: repository implementing business rules? Move them to the domain layer
- **Transaction boundaries**: entities updated together that shouldn't be? Wrong aggregate design
- **Event-driven coupling**: using direct calls where domain events would decouple better?

## When to plan before building

Propose planning when:
- A decision affects multiple bounded contexts or services
- Introducing a new bounded context or significantly changing a boundary
- Integrating with an external system or legacy code
- A performance-critical path is being designed
- Significant refactoring that reshapes domain relationships
