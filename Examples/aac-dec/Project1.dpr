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
