import { Action, ActionPanel, Detail, getFrontmostApplication } from "@raycast/api";
import { useEffect, useState } from "react";
import { inspectFinderSelection } from "./finder-selection";

export default function TestFinderSelection() {
  const [output, setOutput] = useState<string>();

  useEffect(() => {
    const frontmostApp = getFrontmostApplication().then(
      ({ name, bundleId }) => ({ name, bundleId }),
      (error: unknown) => ({ error: String(error) }),
    );

    void Promise.all([inspectFinderSelection(), frontmostApp]).then(([{ paths, from, result }, app]) => {
      setOutput(JSON.stringify({ frontmostApp: app, selectedPaths: paths, from, result }, null, 2));
    });
  }, []);

  return (
    <Detail
      isLoading={output === undefined}
      markdown={output === undefined ? undefined : "```json\n" + output + "\n```"}
      actions={
        output && (
          <ActionPanel>
            <Action.CopyToClipboard title="Copy Test Output" content={output} />
          </ActionPanel>
        )
      }
    />
  );
}
