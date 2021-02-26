program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  audio.wave.reader in 'audio.wave.reader.pas',
  FDK_audio in '..\..\Include\FDK_audio.pas',
  aacenc_lib in '..\..\Include\aacenc_lib.pas';

procedure Usage();
begin
	WriteLn(format('%s [-r bitrate] [-t aot] [-a afterburner] [-s sbr] [-v vbr] in.wav out.aac', [System.IOUtils.TPath.GetFileName(ParamStr(0))]));
	WriteLn('Supported AOTs:');
	WriteLn('    2  - AAC-LC');
	WriteLn('    5  - HE-AAC');
	WriteLn('    29 - HE-AAC v2');
	WriteLn('    23 - AAC-LD');
	WriteLn('    39 - AAC-ELD');
end;

var
  //args
  FParamValue       : string;
  FBitrate          : integer;
  FAot              : integer;
  FAfterburner      : integer;
  FSbr              : integer;
  FVbr              : integer;
  FInFile           : string;
  FOutFile          : string;
  FMode             : Integer;

  FWaveFile         : TWaveReader;
  FOutStream        : TFileStream;

  FHandle           : HANDLE_AACENCODER;
  FInfo             : TAACENC_InfoStruct;
  FErrorCode        : AACENC_ERROR;

  FInBufDesc        : TAACENC_BufDesc;
  FOutBufDesc       : TAACENC_BufDesc;
  FInArgs           : TAACENC_InArgs;
  FOutArgs          : TAACENC_OutArgs;
	FInputBufferSize  : Integer;
	FInputBuffer      : PByte;
  FOutputBufferSize : Integer;
  FOutputBuffer     : PByte;
  FReadBytes        : Integer;
  FInputElemSize    : Integer;
  FInputSize        : Integer;
  FInIdentifier     : AACENC_BufferIdentifier;
  FOutputSize       : Integer;
  FOutputElemSize   : Integer;
  FOutIdentifier    : AACENC_BufferIdentifier;

begin
  try
    ReportMemoryLeaksOnShutdown := true;

    if (ParamCount < 3) then
    begin
      Usage();
      exit;
    end;

    if FindCmdLineSwitch('?') then
    begin
      Usage();
      exit;
    end;

    // [-r bitrate]
    FParamValue := string.Empty;
    FBitrate:= 128000;
    if FindCmdLineSwitch('r', FParamValue, True) then
      FBitrate := StrToInt(FParamValue);

    // [-t aot]
    FParamValue := string.Empty;
    FAot:= Integer(AUDIO_OBJECT_TYPE.AOT_AAC_LC);
    if FindCmdLineSwitch('t', FParamValue, True) then
      FAot := StrToInt(FParamValue);

    //  [-a afterburner]
    FParamValue := string.Empty;
    FAfterburner:= 1;
    if FindCmdLineSwitch('a', FParamValue, True) then
      FAfterburner := StrToInt(FParamValue);

    // [-s sbr]
    FParamValue := string.Empty;
    FSbr:= 0;
    if FindCmdLineSwitch('s', FParamValue, True) then
      FSbr := StrToInt(FParamValue);

    // [-v vbr]
    FParamValue := string.Empty;
    FVbr:= 0;
    if FindCmdLineSwitch('v', FParamValue, True) then
      FVbr := StrToInt(FParamValue);

    // in file (wav)
    FInFile := ParamStr(ParamCount - 1);
    FInFile  := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), FInFile));

    // out file (aac)
	  FOutFile := ParamStr(ParamCount);
 	  FOutFile  := TPath.GetFullPath(TPath.Combine(System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), FOutFile));

    FWaveFile := TWaveReader.Create(FInFile);
    try
      WriteLn(Format('* Read %s: ', [FInFile]));
      WriteLn(Format('   Data size: %d', [FWaveFile.DataChunk.Size div fWaveFile.DataChunk.NumberOfChannel]));
      WriteLn(Format('   Channels count: %d', [FWaveFile.DataChunk.NumberOfChannel]));
      WriteLn(Format('   BitsPerSample: %d', [FWaveFile.FMTChunk.BitsPerSample]));
      WriteLn(Format('   SampleRate: %d', [FWaveFile.FMTChunk.SampleRate]));

      if (FWaveFile.FMTChunk.BitsPerSample <> 16) then
      begin
        writeln(Format('Unsupported WAV sample depth %d',[FWaveFile.FMTChunk.BitsPerSample]));
        exit;
      end;

      case FWaveFile.DataChunk.NumberOfChannel of
        1: FMode := Integer(CHANNEL_MODE.MODE_1);
        2: FMode := Integer(CHANNEL_MODE.MODE_2);
        3: FMode := Integer(CHANNEL_MODE.MODE_1_2);
        4: FMode := Integer(CHANNEL_MODE.MODE_1_2_1);
        5: FMode := Integer(CHANNEL_MODE.MODE_1_2_2);
        6: FMode := Integer(CHANNEL_MODE.MODE_1_2_2_1);
        else
        begin
          writeln(Format('Unsupported WAV channels %d',[FWaveFile.DataChunk.NumberOfChannel]));
          exit;
        end;
      end;


      if (AacEncOpen(FHandle, 0, FWaveFile.DataChunk.NumberOfChannel) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to open encoder');
        exit;
      end;

      if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_AOT, FAot) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to set the AOT');
        exit;
      end;

      if ((FAot = Integer(AUDIO_OBJECT_TYPE.AOT_ER_AAC_ELD)) and (FSbr > 0)) then
      begin
        if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_SBR_MODE, 1) <> AACENC_ERROR.AACENC_OK) then
        begin
          writeln('Unable to set SBR mode for ELD');
          exit;
        end;
      end;

      if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_SAMPLERATE, FWaveFile.FMTChunk.SampleRate) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to set the SampleRate');
        exit;
      end;

      if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_CHANNELMODE, FMode) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to set the channel mode');
        exit;
      end;

      if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_CHANNELORDER, 1) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to set the wav channel order');
        exit;
      end;

      if (FVbr > 0) then
      begin
        if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_BITRATEMODE, FVbr) <> AACENC_ERROR.AACENC_OK) then
        begin
          writeln('Unable to set the VBR bitrate mode');
          exit;
        end;
      end else
      begin
        if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_BITRATE, FBitrate) <> AACENC_ERROR.AACENC_OK) then
        begin
          writeln('Unable to set the bitrate');
          exit;
        end;
      end;

      if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_TRANSMUX, Integer(TRANSPORT_TYPE.TT_MP4_ADTS)) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to set the ADTS transmux');
        exit;
      end;

      if (aacEncoder_SetParam(FHandle, AACENC_PARAM.AACENC_AFTERBURNER, FAfterburner) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to set the afterburner mode');
        exit;
      end;

      if (aacEncEncode(FHandle, nil, nil, nil, nil) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to initialize the encoder');
        exit;
      end;

      if (aacEncInfo(FHandle, @FInfo) <> AACENC_ERROR.AACENC_OK) then
      begin
        writeln('Unable to get the encoder info');
        exit;
      end;

      FOutStream := TFileStream.Create(FOutFile, System.Classes.fmCreate);
      try
        FillChar(FInArgs, SizeOf(TAACENC_InArgs), 0);
        FillChar(FOutArgs, SizeOf(TAACENC_OutArgs), 0);

        FInputBufferSize := FInfo.frameLength * FWaveFile.DataChunk.NumberOfChannel * SizeOf(SmallInt);
        FInputBuffer := AllocMem(FInputBufferSize);
        try

          FOutputBufferSize := FInfo.maxOutBufBytes;
          FOutputBuffer := AllocMem(FOutputBufferSize);
          try
            FInIdentifier := AACENC_BufferIdentifier.IN_AUDIO_DATA;
            FInputElemSize := SizeOf(SmallInt);
            FInputSize := FWaveFile.DataChunk.NumberOfChannel * FInfo.frameLength;
            FillChar(FInBufDesc, SizeOf(TAACENC_BufDesc), 0);
            FInBufDesc.numBufs := 1;
            FInBufDesc.bufs := @FInputBuffer;
            FInBufDesc.bufferIdentifiers := @FInIdentifier;
            FInBufDesc.bufSizes := @FInputSize;
            FInBufDesc.bufElSizes := @FInputElemSize;

            FOutIdentifier := AACENC_BufferIdentifier.OUT_BITSTREAM_DATA;
            FOutputElemSize := SizeOf(Byte);
            FOutputSize := FOutputBufferSize;
            FillChar(FOutBufDesc, SizeOf(TAACENC_BufDesc), 0);
            FOutBufDesc.numBufs := 1;
            FOutBufDesc.bufs := @FOutputBuffer;
            FOutBufDesc.bufferIdentifiers := @FOutIdentifier;
            FOutBufDesc.bufSizes := @FOutputSize;
            FOutBufDesc.bufElSizes := @FOutputElemSize;

            FWaveFile.DataChunk.Possition := 0;
            while True do
            begin
              FReadBytes := FWaveFile.DataChunk.ReadData(FInputBuffer, FInputSize);
              if FInputSize <> FReadBytes then
                FInputSize := FReadBytes;

              if FReadBytes <= 0 then
                break
              else
                FInArgs.numInSamples := FReadBytes div 2;

              FErrorCode := aacEncEncode(FHandle, @FInBufDesc, @FOutBufDesc, @FInArgs, @FOutArgs);
              if FErrorCode <> AACENC_ERROR.AACENC_OK then
              begin
                if (FErrorCode = AACENC_ERROR.AACENC_ENCODE_EOF) then
                  break;

                raise Exception.Create('Encoding failed');
              end;
              if FOutArgs.numOutBytes = 0 then
                continue;

              FOutStream.WriteBuffer(FOutputBuffer^, FOutArgs.numOutBytes);
            end;

            // flush file
            FInArgs.numInSamples := -1;
            FErrorCode := aacEncEncode(FHandle, @FInBufDesc, @FOutBufDesc, @FInArgs, @FOutArgs);
            Assert(FErrorCode in [AACENC_ERROR.AACENC_ENCODE_EOF, AACENC_ERROR.AACENC_OK]);

            if FOutArgs.numOutBytes >= 0 then
              FOutStream.WriteBuffer(FOutputBuffer^, FOutArgs.numOutBytes);

          finally
            FreeMem(FOutputBuffer);
          end;

        finally
          FreeMem(FInputBuffer);
        end;

      finally
        FreeAndNil(FOutStream);
      end;

      aacEncClose(FHandle);

    finally
      FreeAndNil(FWaveFile);
    end;

    writeLn('');
    writeLn(Format('* Finish encode to ACC. %s', [FOutFile]));

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  writeLn;
  write('Press Enter to exit...');
  readln;

end.
