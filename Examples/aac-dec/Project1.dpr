program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  FDK_audio in '..\..\Include\FDK_audio.pas',
  aacdecoder_lib in '..\..\Include\aacdecoder_lib.pas';

const
  OUTPUT_BUFF_SIZE = 8*2*2048;
  INPUT_BUFF_SIZE = 10240;

var
  i             : integer;
  lSourceFile   : string;
  lDumpFile     : string;

  lSourceStream : TFileStream;
  lDumpStream   : TFileStream;

  // fdk-aac
  FHandle       : HANDLE_AACDECODER;
  FLibInfo      : array[0..Integer(FDK_MODULE_LAST)-1] of LIB_INFO;

  FErrorCode    : AAC_DECODER_ERROR;
  FCStreamInfo  : PCStreamInfo;

  // buffers
  FOutputBuff   : PSmallInt;
  FInputBuff    : PByte;
  FReadBytes    : Cardinal;
  FByteFilled   : Cardinal;
  FFrameSize    : Integer;
begin
  try
    ReportMemoryLeaksOnShutdown := true;

    if not FindCmdLineSwitch('i', lSourceFile, True) then
    begin
      writeln(format('Usage: %s -i [AAC_FILE] -dump [RAW_PCM_DATA]', [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
      exit;
    end;
    lSourceFile := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), lSourceFile));

    if not FindCmdLineSwitch('dump', lDumpFile, True) then
      lDumpFile := 'raw_data.pcm';
    lDumpFile := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), lDumpFile));

    // get library info
    writeLn('* LIBFDK-AAC: aacDecoder_GetLibInfo');
    aacDecoder_GetLibInfo(FLibInfo);
    for i := 0 to Integer(FDK_MODULE_ID.FDK_MODULE_LAST) - 1 do
    begin
      if FLibInfo[i].title <> '' then
        writeLn(Format('     %s - %s', [FLibInfo[i].title, LIB_VERSION_STRING(FLibInfo[i])]));
    end;
    writeLn;
    writeLn;

    // init buffer
    GetMem(FOutputBuff, OUTPUT_BUFF_SIZE);
    GetMem(FInputBuff, INPUT_BUFF_SIZE);

    FHandle := aacDecoder_Open(TRANSPORT_TYPE.TT_MP4_ADTS, 1);
    try
    	FErrorCode := aacDecoder_SetParam(FHandle, AAC_CONCEAL_METHOD, 1);
	    FErrorCode := aacDecoder_SetParam(FHandle, AAC_PCM_LIMITER_ENABLE, 0);

      {$REGION 'aacDecoder_ConfigRaw'}
        {$REGION 'Audio Specific Config'}
        (*
          The Audio Specific Config is the global header for MPEG-4 Audio:

          5 bits for object type = 00010 = 2 = AAC low complexity
          4 bits for sampling rate = 0100 = 44100hz
          4 bit for channel = 0010 = 2 channel
          1 bit for frame length flag = 0 for 1024 sample
          1 bit for depends on core coder = 0
          1 bit for extension flag = 0

          frame length flag:
          0: Each packet contains 1024 samples
          1: Each packet contains 960 samples

          The full specification for AudioSpecificConfig is stated in ISO 14496-3 Section 1.6.2.1

          5 bits: object type
          if (object type == 31)
              6 bits + 32: object type
          4 bits: frequency index
          if (frequency index == 15)
              24 bits: frequency
          4 bits: channel configuration
          var bits: AOT Specific Config
          Audio Object Types
          MPEG-4 Audio Object Types:

          0: Null
          1: AAC Main
          2: AAC LC (Low Complexity)
          3: AAC SSR (Scalable Sample Rate)
          4: AAC LTP (Long Term Prediction)
          5: SBR (Spectral Band Replication)
          6: AAC Scalable
          7: TwinVQ
          8: CELP (Code Excited Linear Prediction)
          9: HXVC (Harmonic Vector eXcitation Coding)
          10: Reserved
          11: Reserved
          12: TTSI (Text-To-Speech Interface)
          13: Main Synthesis
          14: Wavetable Synthesis
          15: General MIDI
          16: Algorithmic Synthesis and Audio Effects
          17: ER (Error Resilient) AAC LC
          18: Reserved
          19: ER AAC LTP
          20: ER AAC Scalable
          21: ER TwinVQ
          22: ER BSAC (Bit-Sliced Arithmetic Coding)
          23: ER AAC LD (Low Delay)
          24: ER CELP
          25: ER HVXC
          26: ER HILN (Harmonic and Individual Lines plus Noise)
          27: ER Parametric
          28: SSC (SinuSoidal Coding)
          29: PS (Parametric Stereo)
          30: MPEG Surround
          31: (Escape value)
          32: Layer-1
          33: Layer-2
          34: Layer-3
          35: DST (Direct Stream Transfer)
          36: ALS (Audio Lossless)
          37: SLS (Scalable LosslesS)
          38: SLS non-core
          39: ER AAC ELD (Enhanced Low Delay)
          40: SMR (Symbolic Music Representation) Simple
          41: SMR Main
          42: USAC (Unified Speech and Audio Coding) (no SBR)
          43: SAOC (Spatial Audio Object Coding)
          44: LD MPEG Surround
          45: USAC

          Sampling Frequencies
          There are 13 supported frequencies:

          0: 96000 Hz
          1: 88200 Hz
          2: 64000 Hz
          3: 48000 Hz
          4: 44100 Hz
          5: 32000 Hz
          6: 24000 Hz
          7: 22050 Hz
          8: 16000 Hz
          9: 12000 Hz
          10: 11025 Hz
          11: 8000 Hz
          12: 7350 Hz
          13: Reserved
          14: Reserved
          15: frequency is written explictly
          Channel Configurations
          These are the channel configurations:

          0: Defined in AOT Specifc Config
          1: 1 channel: front-center
          2: 2 channels: front-left, front-right
          3: 3 channels: front-center, front-left, front-right
          4: 4 channels: front-center, front-left, front-right, back-center
          5: 5 channels: front-center, front-left, front-right, back-left, back-right
          6: 6 channels: front-center, front-left, front-right, back-left, back-right, LFE-channel
          7: 8 channels: front-center, front-left, front-right, side-left, side-right, back-left, back-right, LFE-channel
          8-15: Reserved
        *)
        {$ENDREGION}
        //object_type := Byte(AUDIO_OBJECT_TYPE.AOT_AAC_LC);
        //frequency_index:= 3;        // 48000 = 3;
        //number_of_channels:= 2;
        //audio_specific := (object_type shl 11) or (frequency_index shl 7) or (number_of_channels shl 3);
        //GetMem(asc, 2);
        //Move(audio_specific, asc^, SizeOf(audio_specific));
        //audio_specific := PWord(asc)^;
        //ascSize := 2;
        // Audio Specific Config (ASC) or Stream Mux Config (SMC))
        //err := aacDecoder_ConfigRaw(aacDecoder, @asc, @ascSize);
        //if err <> AAC_DEC_OK then
        //  raise Exception.Create('AACDecoderFDKAAC: error aacDecoder_ConfigRaw');
      {$ENDREGION}


      writeLn(Format('* Start Decode AAC file: %s', [lSourceFile]));
      lDumpStream := TFileStream.Create(lDumpFile, System.Classes.fmCreate);
      try
        lSourceStream := TFileStream.Create(lSourceFile, fmOpenRead);
        try
          while lSourceStream.Position < (lSourceStream.Size) do
          begin
            // progress
            write('*');
            FReadBytes:= lSourceStream.ReadData(FInputBuff, INPUT_BUFF_SIZE);
            FByteFilled := FReadBytes;
            FErrorCode := aacDecoder_Fill(FHandle, @FInputBuff, @FReadBytes, FByteFilled);
            if (FErrorCode <> AAC_DEC_OK) then
              raise Exception.CreateFmt('Fill failed: %x', [Integer(FErrorCode)]);
            if (FByteFilled <> 0) then
              WriteLn(Format('Unable to feed all %d input bytes, %d bytes left', [FReadBytes, FByteFilled]));

            while true do
            begin
              FErrorCode := aacDecoder_DecodeFrame(FHandle, PSmallInt(FOutputBuff), OUTPUT_BUFF_SIZE div sizeof(SmallInt), 0);
              if (FErrorCode <> AAC_DEC_OK) then
              begin
                if FErrorCode = AAC_DEC_NOT_ENOUGH_BITS then
                  break;
                writeln(Format('Decode failed: %x', [Integer(FErrorCode)]));
              end;

              FCStreamInfo := aacDecoder_GetStreamInfo(FHandle);
              if ((not assigned(FCStreamInfo)) or (FCStreamInfo^.sampleRate <= 0)) then
                raise Exception.Create('No stream info');

              FFrameSize := FCStreamInfo^.frameSize * FCStreamInfo^.numChannels;
              lDumpStream.WriteBuffer(FOutputBuff^, 2 * FFrameSize);
            end;

          end;
        finally
          FreeAndNil(lSourceStream);
        end;
      finally
        FreeAndNil(lDumpStream);
      end;
    finally
      aacDecoder_Close(FHandle);
      FreeMem(FOutputBuff);
      FreeMem(FInputBuff);
    end;
    writeLn('');
    writeLn(Format('* Finish Decode AAC file. %s', [lDumpFile]));

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  writeLn;
  write('Press Enter to exit...');
  readln;

end.
