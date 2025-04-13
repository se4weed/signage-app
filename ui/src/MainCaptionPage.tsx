import React from "react";

import { Flex, Box, Text } from "@chakra-ui/react";
import { AspectRatio } from "@chakra-ui/react";

import { Colors } from "./theme";
import Api, { CaptionMessage } from "./Api";

import { useKioskContext } from "./KioskProvider";
import { TickProvider } from "./TickProvider";
import { useApiContext } from "./ApiContext";
import { useSearchParams } from "react-router-dom";
import { TrackCaptionStream } from "./TrackCaption";

export const MainCaptionPage: React.FC = () => {
  return (
    <TickProvider>
      <Box w="100vw" h="auto">
        <AspectRatio ratio={16 / 9}>
          <Box bgColor="#000000" bgSize="contain" w="100%" h="100%">
            <MainCaptionInner />
          </Box>
        </AspectRatio>
      </Box>
    </TickProvider>
  );
};

export const MainCaptionInner: React.FC = () => {
  const { track } = useKioskContext();
  const apictx = useApiContext(false);
  const { data: screen } = Api.useScreenControl(apictx, track);

  const [searchParams] = useSearchParams();
  const h = searchParams.get("h") ?? "10%";
  const bgColor = searchParams.get("background_color") ?? "black";
  const dummy = !!searchParams.get("dummy");

  return (
    <Flex
      h="100%"
      w="100%"
      justify="space-between"
      direction="column"
      overflow="hidden"
    >
      <Box w="100%" h={h} overflow="hidden">
        {dummy ? (
          <MainCaptionDummy />
        ) : (
          <TrackCaptionStream
            track={track}
            source={screen?.main_caption ?? "refiner"}
            render={(captions) => <MainCaptionContent captions={captions} />}
          />
        )}
      </Box>
      <Box w="100%" flexGrow={2} backgroundColor={bgColor}></Box>
    </Flex>
  );
};

const MainCaptionContent: React.FC<{ captions: CaptionMessage[] }> = ({
  captions,
}) => {
  const box = React.useRef<HTMLDivElement>(null);
  const [searchParams] = useSearchParams();
  const fontSize = searchParams.get("font_size") ?? "1.2vw";
  const lineHeight = searchParams.get("line_height") ?? "1.50vw";

  const lastCaptions = captions.slice(-4);

  React.useEffect(() => {
    console.debug("caption autoscroll chance");
    if (!box.current) return;
    console.debug("caption autoscroll do");
    const el = box.current;
    el.scrollTop = el.scrollHeight;
  }, [box, lastCaptions]);

  return (
    <Flex
      fontSize={fontSize}
      lineHeight={lineHeight}
      color="white"
      textAlign="left"
      overflowX="hidden"
      overflowY="scroll"
      h="100%"
      w="100%"
      css={{
        "&::-webkit-scrollbar": { display: "none" },
        "&": { scrollbarWidth: "none" },
      }}
      ref={box}
    >
      <Box
        w="100%"
        px="0.5vw"
        css={
          {
            //"&": {
            //  columnCount: 1,
            //  columnWidth: "100%",
            //  columnGap: "0.2vw",
            //  breakAfter: "always",
            //},
          }
        }
      >
        {lastCaptions.map((caption, i) => (
          <Text
            as="span"
            key={`${caption.sequence_id}-${caption.source}`}
            fontWeight={caption.is_partial ? 600 : 400}
            color={i === 0 && !caption.is_partial ? "#707070" : "inherit"}
            marginRight={"1.5rem"}
          >
            {caption.transcript}{" "}
          </Text>
        ))}
      </Box>
    </Flex>
  );
};

const MainCaptionDummy: React.FC = () => {
  const makeCaption = (id: number, transcript: string): CaptionMessage => ({
    from: "dummy",
    kind: "Caption",
    track: "a",
    pid: 0,
    source: "transcribe",
    sequence_id: id,
    round: 1,
    result_id: `dummy-${id}`,
    is_partial: false,
    transcript: transcript,
  });
  const captions: CaptionMessage[] = [
    makeCaption(
      1,
      "1 Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean lorem enim, ultricies pretium iaculis non, sagittis non eros. Quisque sollicitudin laoreet fermentum. Nullam tristique purus ut vulputate porta."
    ),
    makeCaption(
      2,
      "2 Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean lorem enim, ultricies pretium iaculis non, sagittis non eros. Quisque sollicitudin laoreet fermentum. Nullam tristique purus ut vulputate porta."
    ),
    makeCaption(
      3,
      "3 Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean lorem enim, ultricies pretium iaculis non, sagittis non eros. Quisque sollicitudin laoreet fermentum. Nullam tristique purus ut vulputate porta."
    ),
  ];
  return <MainCaptionContent captions={captions} />;
};

export default MainCaptionPage;
