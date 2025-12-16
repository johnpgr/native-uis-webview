// Manual type definitions - single source of truth for TypeScript types

export interface FileInfo {
    name: string
    size: number
    is_dir: boolean
    modified: number
}

// Command definitions for type-safe invoke
export type Commands = {
    readFile: { args: { path: string }; return: { data: string } }
    listDir: { args: { path: string }; return: FileInfo[] }
}
