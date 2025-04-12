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
import { TrackCaptionStream } from "./TrackCaption";

export type Props = {
  track: TrackSlug;
  onUnsubscribe: () => void;
  h?: string;
};

export const ControlCaptionTrack: React.FC<{
  track: TrackSlug;
  source: CaptionSource;
}> = ({ track, source }) => {
  return (
    <>
      <TrackCaptionStream
        track={track}
        source={source}
        render={(captions) => <ControlCaptionTrackInner captions={captions} />}
      />
    </>
  );
};

const ControlCaptionTrackInner: React.FC<{
  captions: CaptionMessage[];
}> = ({ captions }) => {
  let reverseCaptions = captions.slice(0).reverse();
  return (
    <>
      <Box w="100%">
        {reverseCaptions.map((v) => (
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
