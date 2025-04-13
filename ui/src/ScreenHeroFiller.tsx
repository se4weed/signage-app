import React from "react";

import { Center, VStack, Image, Box } from "@chakra-ui/react";
import { LogoIcon } from "./LogoIcon";

export const ScreenHeroFiller: React.FC = () => {
  return (
    <Box
      w="100%"
      h="100%"
      css={{
        "&": {
          backgroundImage: `url(/bg.webp?p=rk25)`,
          backgroundSize: "cover",
          backgroundPosition: "center",
        },
        "& svg": { height: "27vw", width: "auto" },
        "& img": { height: "27vw", width: "auto" },
      }}
    >
      <Center w="100%" h="100%">
        <Image src={`/herologo.svg?p=rk25`} />
      </Center>
    </Box>
  );
};

export const ScreenHeroIconFiller: React.FC = () => {
  return (
    <Center
      w="100%"
      h="100%"
      css={{
        "& svg": { height: "70%", width: "auto" },
        "& img": { height: "70%", width: "auto" },
      }}
    >
      <LogoIcon />
    </Center>
  );
};
