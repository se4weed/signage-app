import { Box } from "@chakra-ui/react";
import { useKioskContext } from "./KioskProvider";

export const SubScreenChatHeader: React.FC = () => {
  const kioskProps = useKioskContext();
  return (
    <Box h="100%" w="100%" fontSize="2.2vw" lineHeight="2.4vw" p="1vw">
      rubykaigi.org/go/discord → #rubykaigi-{kioskProps.track}
    </Box>
  );
};
