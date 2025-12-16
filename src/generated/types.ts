// AUTO-GENERATED - DO NOT EDIT

export interface FileInfo {
  name: string;
  size: number;
  is_dir: boolean;
  modified: number;
}

export interface Config {
  theme: string;
  font_size: number;
  dark_mode: boolean;
  recent_files: string[];
}

export type DialogResult =
  | { type: "cancelled" }
  | { type: "selected"; value: string[] };

