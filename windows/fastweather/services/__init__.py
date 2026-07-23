"""Service layer: stateless network fetchers and the fetch manager.

Services return plain data and have no wx dependency, so they are unit-testable
without a GUI. The FetchManager bridges background results back to the wx UI
thread via posted events.
"""
