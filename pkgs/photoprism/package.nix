{
  fetchurl,
  fetchzip,
  photoprism,
}:

let
  scrfd = fetchurl {
    url = "https://raw.githubusercontent.com/laolaolulu/FaceTrain/master/model/scrfd/scrfd_500m_bnkps_shape640x640.onnx";
    hash = "sha256-rnIYVlPieaogVrKIZioZ7DUZztVCbSre/74FioY2miQ=";
  };

  onnxruntime = fetchzip {
    url = "https://github.com/microsoft/onnxruntime/releases/download/v1.26.0/onnxruntime-linux-x64-1.26.0.tgz";
    hash = "sha256-pSA5JzCpVYMhP0r2l2pyYXhgBYtPOOCEKY0eG9TnXCM=";
  };
in
photoprism.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    mkdir -p "$out/share/photoprism/models/scrfd"
    ln -s ${scrfd} "$out/share/photoprism/models/scrfd/scrfd.onnx"

    wrapProgram "$out/bin/photoprism" \
      --prefix LD_LIBRARY_PATH : "${onnxruntime}/lib"
  '';

  passthru = (old.passthru or { }) // {
    inherit onnxruntime scrfd;
  };
})
