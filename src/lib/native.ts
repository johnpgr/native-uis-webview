import type { Commands } from "./types"

/**
 * Type-safe invoke function - the single entry point for all native calls.
 *
 * @example
 * const files = await invoke("listDir", { path: "/home" });
 */
export async function invoke<K extends keyof Commands>(
    command: K,
    args: Commands[K]["args"]
): Promise<Commands[K]["return"]> {
    return window.__invoke(command, args)
}
