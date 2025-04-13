import React, { useCallback, useMemo } from "react";
import { useSearchParams } from "react-router-dom";

import { Box, Skeleton, Text } from "@chakra-ui/react";

import { Colors } from "./theme";
import { useApiContext } from "./ApiContext";
import {
  PubsubMessage,
  PubsubMessageHandler,
  PubsubSubscription,
} from "./PubsubProvider";
import Api from "./Api";
import {
  ApiPubsubMessage,
  CaptionMessage,
  CaptionSource,
  TrackSlug,
} from "./Api";

export type Props = {
  track: TrackSlug;
};

const CAPTION_BACKTRACK = 50;

export const TrackCaption: React.FC<Props> = ({ track }) => {
  const apictx = useApiContext(false);
  const { data: screen } = Api.useScreenControl(apictx, track);

  if (!screen) return <Skeleton h="100%" w="100%" />;
  return (
    <>
      <TrackCaptionStream
        track={track}
        source={screen.subscreen_caption ?? "refiner"}
        render={(captions) => (
          <TrackCaptionInner track={track} captions={captions} />
        )}
      />
    </>
  );
};

export const TrackCaptionInner: React.FC<{
  track: TrackSlug;
  captions: CaptionMessage[];
}> = ({ captions: origCaptions }) => {
  const box = React.useRef<HTMLDivElement>(null);
  const [searchParams] = useSearchParams();
  const hidePartial = !!searchParams.get("hide_partial");

  const captions = hidePartial
    ? origCaptions.filter((v) => !v.is_partial)
    : origCaptions;

  const lastcaption =
    captions.length > 0 ? captions[captions.length - 1] : undefined;
  React.useEffect(() => {
    console.debug("caption autoscroll chance");
    if (!box.current) return;
    console.debug("caption autoscroll do");
    const el = box.current;
    el.scrollTop = el.scrollHeight;
  }, [box, captions, lastcaption?.sequence_id, lastcaption?.round]);

  return (
    <>
      <Box
        h="100%"
        w="100%"
        overflowX="hidden"
        overflowY="hidden"
        wordBreak="break-word"
        bgColor="#000000"
        px="8px"
        py="12px"
        css={{
          "&::-webkit-scrollbar": { display: "none" },
          "&": { scrollbarWidth: "none" },
        }}
        ref={box}
      >
        <Text color="#FFFFFF">
          {captions.map((v) => (
            <Text as="span" key={v.sequence_id}>
              {v.transcript}{" "}
            </Text>
          ))}
        </Text>
      </Box>
    </>
  );
};

export const TrackCaptionStream: React.FC<{
  track: TrackSlug;
  source: CaptionSource;
  render: (captions: CaptionMessage[]) => React.ReactNode;
}> = ({ track, source, render }) => {
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

            newCaptions.sort((a, b) => a.sequence_id - b.sequence_id);

            if (newCaptions.length > CAPTION_BACKTRACK) {
              newCaptions.shift();
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

  return (
    <>
      {pubsubStones}
      {render(captions)}
    </>
  );
};

export default TrackCaption;
