import React, { useState } from "react";

import {
  Flex,
  Box,
  Skeleton,
  Tag,
  useDisclosure,
  IconButton,
  Tabs,
  TabList,
  TabPanel,
  TabPanels,
  Tab,
} from "@chakra-ui/react";
import { Text } from "@chakra-ui/react";

import ControlCaptionTrack from "./ControlCaptionTrack";
import { Api } from "./Api";
import { Colors } from "./theme";

export const ControlCaptionPage: React.FC = () => {
  const { data: config } = Api.useConfig();

  if (!config)
    return (
      <Box>
        <Skeleton />
      </Box>
    );

  return (
    <Box>
      <Tabs variant="soft-rounded">
        <TabList>
          {config.tracks.map((slug) => (
            <Tab key={slug}>{slug}</Tab>
          ))}
        </TabList>
        <TabPanels>
          {config.tracks.map((slug) => {
            return (
              <TabPanel key={slug}>
                <Box
                  border="1px solid"
                  borderColor={Colors.chatBorder2}
                  backgroundColor="white"
                  w={["100%", "100%", "auto", "auto"]}
                  flexGrow={1}
                  minW={["auto", "auto", "320px", "330px"]}
                  mt={3}
                  mx={[3, 3, 1, 1]}
                  p={4}
                >
                  <Flex>
                    <ControlCaptionTrack track={slug} source="transcribe" />
                    <ControlCaptionTrack track={slug} source="refiner" />
                  </Flex>
                </Box>
              </TabPanel>
            );
          })}
        </TabPanels>
      </Tabs>
    </Box>
  );

  //  return <Box>{/*<ControlScreenForm />*/}</Box>;
};
export default ControlCaptionPage;
