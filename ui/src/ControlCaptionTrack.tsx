import React, { useCallback, useMemo } from "react";

import {
  Box,
  Card,
  CardBody,
  CardFooter,
  Skeleton,
  Text,
} from "@chakra-ui/react";

import { Colors } from "./theme";
import { useApiContext } from "./ApiContext";
import {
  PubsubMessage,
  PubsubMessageHandler,
  PubsubSubscription,
} from "./PubsubProvider";
import {
  ApiPubsubMessage,
  CaptionMessage,
  CaptionSource,
  TrackSlug,
} from "./Api";

export type Props = {
  track: TrackSlug;
  onUnsubscribe: () => void;
  h?: string;
};

const CAPTION_BACKTRACK = 50;

export const ControlCaptionTrack: React.FC<{
  track: TrackSlug;
  source: CaptionSource;
}> = ({ track, source }) => {
  const apictx = useApiContext(false);

  const [captions, setCaptions] = React.useState<CaptionMessage[]>([]);

  const onMessage = useCallback(
    (message: PubsubMessage) => {
      const payload: ApiPubsubMessage = message.payload as ApiPubsubMessage; // XXX:
      switch (payload.kind) {
        case "Caption": {
          if (payload.source !== source) return;
          setCaptions((prevCaptions) => {
            const newCaptions = [...prevCaptions];
            const existingCaptionIdx = newCaptions.findIndex(
              (c) =>
                payload.sequence_id === c.sequence_id &&
                payload.source === c.source
            );
            if (existingCaptionIdx < 0) {
              newCaptions.push(payload);
            } else {
              const existingCaption = newCaptions[existingCaptionIdx];
              if (payload.round > existingCaption.round) {
                newCaptions[existingCaptionIdx] = payload;
              }
            }

            newCaptions.sort((a, b) => b.sequence_id - a.sequence_id);

            if (newCaptions.length > CAPTION_BACKTRACK) {
              newCaptions.pop();
            }
            return newCaptions;
          });
          break;
        }
      }
    },
    [source, setCaptions]
  );
  const pubsubStones = useMemo(() => {
    if (!apictx) return;
    const topic = `${apictx.config.iot_topic_prefix}/uplink/all/captions/${track}`;
    return (
      <>
        <PubsubMessageHandler topic={topic} onMessage={onMessage} />
        <PubsubSubscription
          packet={{
            subscriptions: [
              {
                qos: 0,
                topicFilter: topic,
              },
            ],
          }}
        />
      </>
    );
  }, [apictx, track, onMessage]);

  if (!apictx) return <Skeleton />;
  console.log({ captions, source });
  return (
    <>
      {pubsubStones}
      <Box w="100%">
        {captions.map((v) => (
          <Card key={`${v.source} ${v.sequence_id}`} mb={2}>
            <CardBody>{v.transcript}</CardBody>
            <CardFooter>
              <Text fontSize="xs">
                {v.is_partial ? "♻️" : "✅"} {v.result_id} {v.sequence_id}{" "}
                {v.round} {v.source}
              </Text>
            </CardFooter>
          </Card>
        ))}
      </Box>
    </>
  );
};
export default ControlCaptionTrack;
