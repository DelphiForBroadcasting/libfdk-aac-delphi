program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  FDK_audio in '..\..\Include\FDK_audio.pas',
  aacdecoder_lib in '..\..\Include\aacdecoder_lib.pas',
  aacenc_lib in '..\..\Include\aacenc_lib.pas';

var
  FEncLibInfos: array[FDK_MODULE_ID] of LIB_INFO;
  FDecLibInfos: array[FDK_MODULE_ID] of LIB_INFO;
  FModuleID: FDK_MODULE_ID;

begin
  try
    ReportMemoryLeaksOnShutdown := true;

    // encoder
    Writeln('* LIBFDK-AAC: AacEncGetLibInfo');
    AacEncGetLibInfo(FEncLibInfos[FDK_MODULE_ID.FDK_NONE]);
    for FModuleID := Low(FDK_MODULE_ID) to High(FDK_MODULE_ID) do
      if FEncLibInfos[FModuleID].title <> nil then
        Writeln(String.Format('  %s %s (build %s, %s)',
          [string(FEncLibInfos[FModuleID].title),
          LIB_VERSION_STRING(FEncLibInfos[FModuleID]),
          string(FEncLibInfos[FModuleID].build_date),
          string(FEncLibInfos[FModuleID].build_time)]));

    Writeln('');

    // decoder
    Writeln('* LIBFDK-AAC: aacDecoder_GetLibInfo');
    aacDecoder_GetLibInfo(FDecLibInfos[FDK_MODULE_ID.FDK_NONE]);
    for FModuleID := Low(FDK_MODULE_ID) to High(FDK_MODULE_ID) do
      if FDecLibInfos[FModuleID].title <> nil then
        Writeln(Format('  %s %s (build %s, %s)',
          [string(FDecLibInfos[FModuleID].title),
          LIB_VERSION_STRING(FDecLibInfos[FModuleID]),
          string(FDecLibInfos[FModuleID].build_date),
          string(FDecLibInfos[FModuleID].build_time)]));

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  writeLn;
  write('Press Enter to exit...');
  readln;

end.
