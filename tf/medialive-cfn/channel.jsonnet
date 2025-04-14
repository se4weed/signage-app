local tags = std.parseJson(std.extVar('DEFAULT_TAGS')) + { Component: 'captioner' };
local tagsToVpcTags = function(o) [{ Key: key, Value: o[key] } for key in std.objectFields(o)];

{
  AWSTemplateFormatVersion: '2010-09-09',

  Parameters: {
    ChannelName: { Type: 'String' },
    StreamKey: { Type: 'String' },
    Subnet1Id: { Type: 'String' },
    Subnet2Id: { Type: 'String' },
    RoleArn: { Type: 'String' },
    VpcSgIds: { Type: 'String' },
    MedialiveSgPublicId: { Type: 'String' },
    CaptionerUrl: { Type: 'String' },
    NamePrefix: { Type: 'String' },
    S3UrlBase: { Type: 'String' },
  },

  Outputs: {
    PublicOutboundEip: { Value: { 'Fn::GetAtt': ['ChannelEip', 'AllocationId'] } },
    //PrivateInputId: { Value: { 'Fn::GetAtt': ['InputPrivate', 'Id'] } },
    //PublicInputId: { Value: { 'Fn::GetAtt': ['InputPublic', 'Id'] } },
    PrivateInputId: { Value: { Ref: 'InputPrivate' } },
    PublicInputId: { Value: { Ref: 'InputPublic' } },


    PrivateInputPath: { Value: { 'Fn::Sub': '${NamePrefix}-${ChannelName}-private/${StreamKey}-i-${ChannelName}' } },
    PublicInputPath: { Value: { 'Fn::Sub': '${NamePrefix}-${ChannelName}-public/${StreamKey}-e-${ChannelName}' } },
  },

  Resources: {
    ChannelEip: {
      Type: 'AWS::EC2::EIP',
      Properties: {
        Domain: 'vpc',
        Tags: tagsToVpcTags(tags {
          Name: { 'Fn::Sub': '${NamePrefix}-medialive-${ChannelName}' },
        }),
      },
    },

    InputPrivate: {
      local name = { 'Fn::Sub': '${NamePrefix}-${ChannelName}-private/${StreamKey}-i-${ChannelName}' },
      Type: 'AWS::MediaLive::Input',
      Properties: {
        Type: 'RTMP_PUSH',
        Destinations: [
          { StreamName: name },
        ],
        RoleArn: { 'Fn::Sub': '${RoleArn}' },
        Vpc: {
          SecurityGroupIds: { 'Fn::Split': [',', { 'Fn::Sub': '${VpcSgIds}' }] },
          SubnetIds: [{ 'Fn::Sub': '${Subnet1Id}' }, { 'Fn::Sub': '${Subnet2Id}' }],
        },
        Tags: tags {
          Name: { 'Fn::Sub': '${NamePrefix}-${ChannelName}-private' },
        },
      },
    },

    InputPublic: {
      local name = { 'Fn::Sub': '${NamePrefix}-${ChannelName}-public/${StreamKey}-e-${ChannelName}' },
      Type: 'AWS::MediaLive::Input',
      Properties: {
        Type: 'RTMP_PUSH',
        Destinations: [
          { StreamName: name },
        ],
        InputSecurityGroups: [{ 'Fn::Sub': '${MedialiveSgPublicId}' }],
        Tags: tags {
          Name: { 'Fn::Sub': '${NamePrefix}-${ChannelName}-public' },
        },
      },
    },

    Channel: {
      Type: 'AWS::MediaLive::Channel',
      Properties: {
        Name: { 'Fn::Sub': '${NamePrefix}-${ChannelName}' },
        ChannelClass: 'SINGLE_PIPELINE',
        RoleArn: { 'Fn::Sub': '${RoleArn}' },
        LogLevel: 'INFO',
        EncoderSettings: {
          VideoDescriptions: [
            {
              Name: 'caption1v',
              CodecSettings: {
                H264Settings: {
                  AfdSignaling: 'NONE',
                  ColorMetadata: 'INSERT',
                  AdaptiveQuantization: 'HIGH',
                  Bitrate: 4000000,
                  EntropyEncoding: 'CABAC',
                  FlickerAq: 'ENABLED',
                  ForceFieldPictures: 'DISABLED',
                  FramerateControl: 'SPECIFIED',
                  FramerateNumerator: 30000,
                  FramerateDenominator: 1001,
                  GopBReference: 'DISABLED',
                  GopClosedCadence: 1,
                  GopNumBFrames: 3,
                  GopSize: 2,
                  GopSizeUnits: 'SECONDS',
                  SubgopLength: 'FIXED',
                  ScanType: 'PROGRESSIVE',
                  Level: 'H264_LEVEL_AUTO',
                  LookAheadRateControl: 'HIGH',
                  NumRefFrames: 3,
                  ParControl: 'SPECIFIED',
                  ParNumerator: 1,
                  ParDenominator: 1,
                  Profile: 'HIGH',
                  RateControlMode: 'CBR',
                  Syntax: 'DEFAULT',
                  SceneChangeDetect: 'ENABLED',
                  Slices: 4,
                  SpatialAq: 'ENABLED',
                  TemporalAq: 'ENABLED',
                  TimecodeInsertion: 'DISABLED',
                },
              },
              RespondToAfd: 'NONE',
              Sharpness: 50,
              ScalingBehavior: 'DEFAULT',
              Width: 1280,  // Width: 1920,
              Height: 720,  // Height: 1080,
            },
            {
              Name: 'caption2v',
              CodecSettings: {
                H264Settings: {
                  AfdSignaling: 'NONE',
                  ColorMetadata: 'INSERT',
                  AdaptiveQuantization: 'HIGH',
                  Bitrate: 3000000,
                  MaxBitrate: 6000000,
                  EntropyEncoding: 'CABAC',
                  FlickerAq: 'ENABLED',
                  ForceFieldPictures: 'DISABLED',
                  FramerateControl: 'SPECIFIED',
                  FramerateNumerator: 30000,
                  FramerateDenominator: 1001,
                  GopBReference: 'DISABLED',
                  GopClosedCadence: 1,
                  GopNumBFrames: 3,
                  GopSize: 2,
                  GopSizeUnits: 'SECONDS',
                  SubgopLength: 'FIXED',
                  ScanType: 'PROGRESSIVE',
                  Level: 'H264_LEVEL_AUTO',
                  LookAheadRateControl: 'HIGH',
                  NumRefFrames: 3,
                  ParControl: 'SPECIFIED',
                  ParNumerator: 1,
                  ParDenominator: 1,
                  Profile: 'HIGH',
                  RateControlMode: 'VBR',
                  Syntax: 'DEFAULT',
                  SceneChangeDetect: 'ENABLED',
                  Slices: 4,
                  SpatialAq: 'ENABLED',
                  TemporalAq: 'ENABLED',
                  TimecodeInsertion: 'DISABLED',
                },
              },
              RespondToAfd: 'NONE',
              Sharpness: 50,
              ScalingBehavior: 'DEFAULT',
              Width: 1280,  // Width: 1920,
              Height: 720,  // Height: 1080,
            },
          ],
          AudioDescriptions: [
            // {
            //   Name: 'ivs1a',
            //   CodecSettings: {
            //     AacSettings: {
            //       InputType: 'NORMAL',
            //       Bitrate: 128000,
            //       CodingMode: 'CODING_MODE_2_0',
            //       RawFormat: 'NONE',
            //       Spec: 'MPEG4',
            //       Profile: 'LC',
            //       RateControlMode: 'CBR',
            //       SampleRate: 48000,
            //     },
            //   },
            //   AudioTypeControl: 'FOLLOW_INPUT',
            //   LanguageCodeControl: 'FOLLOW_INPUT',
            // },
            {
              Name: 'caption1a',
              CodecSettings: {
                AacSettings: {
                  InputType: 'NORMAL',
                  Bitrate: 128000,
                  CodingMode: 'CODING_MODE_1_0',
                  RawFormat: 'NONE',
                  Spec: 'MPEG4',
                  Profile: 'LC',
                  RateControlMode: 'CBR',
                  SampleRate: 48000,
                },
              },
              AudioTypeControl: 'FOLLOW_INPUT',
              LanguageCodeControl: 'FOLLOW_INPUT',
            },
          ],
          OutputGroups: [
            // {
            //   Name: 'ivs',
            //   OutputGroupSettings: {
            //     RtmpGroupSettings: {
            //       InputLossAction: 'PAUSE_OUTPUT',
            //     },
            //   },
            //   Outputs: [
            //     {
            //       OutputName: 'ivs1',
            //       OutputSettings: {
            //         RtmpOutputSettings: {
            //           Destination: { DestinationRefId: 'ivs1' },
            //           ConnectionRetryInterval: 2,
            //           NumRetries: 10,
            //           CertificateMode: 'VERIFY_AUTHENTICITY',
            //         },
            //       },
            //       VideoDescriptionName: 'ivs1v',
            //       AudioDescriptionNames: ['ivs1a'],
            //     },
            //   ],
            // },
            {
              Name: 'captioner',
              OutputGroupSettings: {
                UdpGroupSettings: {
                  InputLossAction: 'EMIT_PROGRAM',
                  //timedMetadataId3Period: 10,
                  //timedMetadataId3Frame: 'PRIV',
                },
              },
              Outputs: [
                {
                  OutputName: 'caption1',
                  OutputSettings: {
                    UdpOutputSettings: {
                      Destination: { DestinationRefId: 'captioner1' },
                      BufferMsec: 1000,
                      ContainerSettings: {
                        M2tsSettings: {
                          //CcDescriptor: 'DISABLED',
                          //ebif: 'NONE',
                          //nielsenId3Behavior: 'NO_PASSTHROUGH',
                          //programNum: 1,
                          //patInterval: 100,
                          //pmtInterval: 100,
                          //pcrControl: 'PCR_EVERY_PES_PACKET',
                          //pcrPeriod: 40,
                          //timedMetadataBehavior: 'NO_PASSTHROUGH',
                          //bufferModel: 'MULTIPLEX',
                          //rateMode: 'CBR',
                          //audioBufferModel: 'ATSC',
                          //audioStreamType: 'DVB',
                          //audioFramesPerPes: 2,
                          //segmentationStyle: 'MAINTAIN_CADENCE',
                          //segmentationMarkers: 'NONE',
                          //ebpPlacement: 'VIDEO_AND_AUDIO_PIDS',
                          //ebpAudioInterval: 'VIDEO_INTERVAL',
                          //esRateInPes: 'EXCLUDE',
                          //arib: 'DISABLED',
                          //aribCaptionsPidControl: 'AUTO',
                          //absentInputAudioBehavior: 'ENCODE_SILENCE',
                          //pmtPid: '480',
                          //videoPid: '481',
                          //audioPids: '482-498',
                          //dvbTeletextPid: '499',
                          //dvbSubPids: '460-479',
                          //scte27Pids: '450-459',
                          //scte35Pid: '500',
                          //scte35Control: 'NONE',
                          //klv: 'NONE',
                          //klvDataPids: '501',
                          //timedMetadataPid: '502',
                          //etvPlatformPid: '504',
                          //etvSignalPid: '505',
                          //aribCaptionsPid: '507',
                        },
                      },
                    },
                  },
                  AudioDescriptionNames: ['caption1a'],
                },
              ],
            },
            {
              Name: 'archive',
              OutputGroupSettings: {
                ArchiveGroupSettings: {
                  Destination: {
                    DestinationRefId: 'archive1',
                  },
                  RolloverInterval: 300,
                },
              },
              Outputs: [
                {
                  VideoDescriptionName: 'caption2v',
                  AudioDescriptionNames: [
                    'caption1a',
                  ],
                  CaptionDescriptionNames: [],
                  OutputName: 'archive1',
                  OutputSettings: {
                    ArchiveOutputSettings: {
                      ContainerSettings: {
                        M2tsSettings: {
                          AbsentInputAudioBehavior: 'ENCODE_SILENCE',
                          Arib: 'DISABLED',
                          AribCaptionsPid: '507',
                          AribCaptionsPidControl: 'AUTO',
                          AudioBufferModel: 'ATSC',
                          AudioFramesPerPes: 2,
                          AudioPids: '482-498',
                          AudioStreamType: 'DVB',
                          BufferModel: 'MULTIPLEX',
                          CcDescriptor: 'DISABLED',
                          DvbSubPids: '460-479',
                          DvbTeletextPid: '499',
                          Ebif: 'NONE',
                          EbpAudioInterval: 'VIDEO_INTERVAL',
                          EbpPlacement: 'VIDEO_AND_AUDIO_PIDS',
                          EsRateInPes: 'EXCLUDE',
                          EtvPlatformPid: '504',
                          EtvSignalPid: '505',
                          Klv: 'NONE',
                          KlvDataPids: '501',
                          NielsenId3Behavior: 'NO_PASSTHROUGH',
                          PatInterval: 100,
                          PcrControl: 'PCR_EVERY_PES_PACKET',
                          PcrPeriod: 40,
                          PmtInterval: 100,
                          PmtPid: '480',
                          ProgramNum: 1,
                          RateMode: 'CBR',
                          Scte27Pids: '450-459',
                          Scte35Control: 'NONE',
                          Scte35Pid: '500',
                          SegmentationMarkers: 'NONE',
                          SegmentationStyle: 'MAINTAIN_CADENCE',
                          TimedMetadataBehavior: 'NO_PASSTHROUGH',
                          TimedMetadataPid: '502',
                          VideoPid: '481',
                        },
                      },
                      NameModifier: '_1',
                    },
                  },
                },
              ],
            },
            {
              Name: 'live',
              OutputGroupSettings: {
                HlsGroupSettings: {
                  AdMarkers: [],
                  CaptionLanguageMappings: [],
                  CaptionLanguageSetting: 'OMIT',
                  ClientCache: 'ENABLED',
                  CodecSpecification: 'RFC_4281',
                  Destination: {
                    DestinationRefId: 'live1',
                  },
                  DirectoryStructure: 'SINGLE_DIRECTORY',
                  DiscontinuityTags: 'INSERT',
                  HlsId3SegmentTagging: 'DISABLED',
                  IFrameOnlyPlaylists: 'DISABLED',
                  IncompleteSegmentBehavior: 'AUTO',
                  IndexNSegments: 20,
                  InputLossAction: 'PAUSE_OUTPUT',
                  IvInManifest: 'INCLUDE',
                  IvSource: 'FOLLOWS_SEGMENT_NUMBER',
                  KeepSegments: 41,
                  ManifestCompression: 'NONE',
                  ManifestDurationFormat: 'FLOATING_POINT',
                  Mode: 'LIVE',
                  OutputSelection: 'MANIFESTS_AND_SEGMENTS',
                  ProgramDateTime: 'EXCLUDE',
                  ProgramDateTimeClock: 'INITIALIZE_FROM_OUTPUT_TIMECODE',
                  ProgramDateTimePeriod: 600,
                  RedundantManifest: 'DISABLED',
                  SegmentLength: 3,
                  SegmentationMode: 'USE_SEGMENT_DURATION',
                  SegmentsPerSubdirectory: 10000,
                  StreamInfResolution: 'INCLUDE',
                  TimedMetadataId3Frame: 'PRIV',
                  TimedMetadataId3Period: 10,
                  TsFileMode: 'SEGMENTED_FILES',
                },
              },
              Outputs: [
                {
                  VideoDescriptionName: 'caption1v',
                  AudioDescriptionNames: [
                    'caption1a',
                  ],
                  CaptionDescriptionNames: [],
                  OutputName: 'live1',
                  OutputSettings: {
                    HlsOutputSettings: {
                      H265PackagingType: 'HVC1',
                      HlsSettings: {
                        StandardHlsSettings: {
                          AudioRenditionSets: 'program_audio',
                          M3u8Settings: {
                            AudioFramesPerPes: 4,
                            AudioPids: '492-498',
                            NielsenId3Behavior: 'NO_PASSTHROUGH',
                            PcrControl: 'PCR_EVERY_PES_PACKET',
                            PmtPid: '480',
                            ProgramNum: 1,
                            Scte35Behavior: 'NO_PASSTHROUGH',
                            Scte35Pid: '500',
                            TimedMetadataBehavior: 'NO_PASSTHROUGH',
                            TimedMetadataPid: '502',
                            VideoPid: '481',
                            KlvBehavior: 'NO_PASSTHROUGH',
                          },
                        },
                      },
                      NameModifier: '_1',
                    },
                  },
                },
              ],
            },
          ],
          TimecodeConfig: {
            Source: 'EMBEDDED',
          },
        },
        local inputAttachmentInputSettings = {
          SourceEndBehavior: 'CONTINUE',
          InputFilter: 'AUTO',
          FilterStrength: 1,
          DeblockFilter: 'DISABLED',
          DenoiseFilter: 'DISABLED',
        },
        InputAttachments: [
          {
            InputAttachmentName: { 'Fn::Sub': '${ChannelName}-private' },
            InputId: { Ref: 'InputPrivate' },
            InputSettings: inputAttachmentInputSettings,
          },
          {
            InputAttachmentName: { 'Fn::Sub': '${ChannelName}-public' },
            InputId: { Ref: 'InputPublic' },
            InputSettings: inputAttachmentInputSettings,
          },
        ],
        InputSpecification: {
          Codec: 'AVC',
          Resolution: 'HD',
          MaximumBitrate: 'MAX_10_MBPS',
        },
        Destinations: [
          // {
          //   Id: 'ivs1',
          //   Settings: [
          //     {
          //       Url: { 'Fn::Sub': '${IvsUrl}' },
          //       StreamName: { 'Fn::Sub': '${IvsKey}' },
          //     },
          //   ],
          // },
          {
            Id: 'captioner1',
            Settings: [
              {
                Url: { 'Fn::Sub': '${CaptionerUrl}' },
              },
            ],
          },
          {
            Id: 'archive1',
            MediaPackageSettings: [],
            Settings: [
              {
                Url: { 'Fn::Sub': '${S3UrlBase}archive/archive_$dt$' },
              },
            ],
            SrtSettings: [],
          },
          {
            Id: 'live1',
            MediaPackageSettings: [],
            Settings: [
              {
                Url: { 'Fn::Sub': '${S3UrlBase}live/live' },
              },
            ],
            SrtSettings: [],
          },
        ],
        Vpc: {
          SecurityGroupIds: { 'Fn::Split': [',', { 'Fn::Sub': '${VpcSgIds}' }] },
          SubnetIds: [{ 'Fn::Sub': '${Subnet1Id}' }],
          PublicAddressAllocationIds: [{ 'Fn::GetAtt': ['ChannelEip', 'AllocationId'] }],
        },
        Tags: tags {
          Name: { 'Fn::Sub': '${NamePrefix}-${ChannelName}' },
        },
      },
    },

  },
}
