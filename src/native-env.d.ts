import type { FileInfo, Config } from "./generated/types.ts"

declare global {
    interface Window {
        readFile(path: string): Promise<{ data: string }>
        listDir(path: string): Promise<FileInfo[]>
        getConfig(): Promise<Config>
        setConfig(config: Config): Promise<void>
    }
}

