import type { FileInfo } from "./generated/types"

export async function readFile(path: string): Promise<Uint8Array> {
    const result = await window.readFile(path)
    return Uint8Array.from(atob(result.data), (c) => c.charCodeAt(0))
}

export async function listDir(path: string): Promise<FileInfo[]> {
    return await window.listDir(path)
}
