declare global {
  interface Window {
    __invoke<T = unknown>(command: string, args: unknown): Promise<T>
  }
}

export {}
