import React, { Suspense } from "react"
import { listDir } from "./native"

const filesPromise = listDir("/home/joao").then((files) =>
    files.map((file) => file.name)
)

function FileList() {
    const files = React.use(filesPromise)

    return (
        <ul>
            {files.map((file, index) => (
                <li key={index}>{file}</li>
            ))}
        </ul>
    )
}

export function App() {
    return (
        <div>
            <h1 className="text-4xl text-red-500 font-bold">Hello, World</h1>
            <Suspense fallback={<div>Loading...</div>}>
                <FileList />
            </Suspense>
        </div>
    )
}
