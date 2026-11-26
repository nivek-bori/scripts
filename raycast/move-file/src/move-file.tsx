import { Action, ActionPanel, environment, Form, popToRoot, showToast, Toast } from "@raycast/api";
import { execFile } from "node:child_process";
import { join } from "node:path";
import { useEffect, useRef, useState } from "react";
import { inspectFinderSelection } from "./finder-selection";

function runMove(from: string, to: string): Promise<string> {
  const script = join(environment.assetsPath, "move.sh");
  return new Promise((resolve, reject) => {
    execFile("/bin/bash", [script, from, to], (error, stdout, stderr) => {
      if (error) {
        reject(new Error(stderr.trimEnd() || error.message));
        return;
      }
      resolve(stdout.trimEnd());
    });
  });
}

export default function MoveFile() {
  const [initialSource, setInitialSource] = useState<string>();
  const [editedSource, setEditedSource] = useState<string>();
  const [destinationError, setDestinationError] = useState<string>();
  const isMoving = useRef(false);

  useEffect(() => {
    void inspectFinderSelection().then(({ from }) => setInitialSource(from));
  }, []);

  const source = editedSource ?? initialSource ?? "";

  async function handleSubmit({ to }: { to: string }) {
    if (isMoving.current) return;
    if (!to) {
      setDestinationError("Enter a destination path.");
      return;
    }

    isMoving.current = true;
    try {
      const message = await runMove(source, to);
      await showToast({ style: Toast.Style.Success, title: "Move Complete", message });
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Move Failed",
        message: error instanceof Error ? error.message : String(error),
      });
      return;
    } finally {
      isMoving.current = false;
    }
    await popToRoot();
  }

  if (initialSource === undefined) return <Form isLoading />;

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Move File" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="from"
        title="From"
        value={source}
        onChange={setEditedSource}
        placeholder="Newest file in Downloads"
        autoFocus={initialSource === ""}
      />
      <Form.TextField
        id="to"
        title="To"
        placeholder="Destination file or directory path"
        autoFocus={initialSource !== ""}
        error={destinationError}
        onChange={() => setDestinationError(undefined)}
      />
    </Form>
  );
}
