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
          backgroundImage: `url(/bg.webp?p=rk26)`,
          backgroundSize: "cover",
          backgroundPosition: "center",
          border: "solid white 2.7vh",
          borderRadius: "4vh"
        },
        "& svg": { height: "31vw", width: "auto" },
        "& img": { height: "31vw", width: "auto" },
      }}
    >
      <Center w="100%" h="100%">
        <Image src={`/herologo.svg?p=rk26`} />
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
