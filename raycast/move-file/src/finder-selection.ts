import { getSelectedFinderItems } from "@raycast/api";
import { stat } from "node:fs/promises";

interface FinderSelection {
  paths: string[];
  from: string;
  result: string;
}

export async function inspectFinderSelection(): Promise<FinderSelection> {
  let paths: string[];
  try {
    paths = (await getSelectedFinderItems()).map(({ path }) => path);
  } catch (error) {
    return { paths: [], from: "", result: `Finder selection lookup failed: ${String(error)}` };
  }

  if (paths.length === 0) {
    return { paths, from: "", result: "Finder reported no selected items." };
  }
  if (paths.length > 1) {
    return { paths, from: "", result: "Select exactly one file to prefill From." };
  }

  const [path] = paths;
  try {
    if ((await stat(path)).isFile()) {
      return { paths, from: path, result: "The selected file can prefill From." };
    }
    return { paths, from: "", result: "The selected item is not a regular file." };
  } catch (error) {
    return { paths, from: "", result: `Could not check the selected path: ${String(error)}` };
  }
}
