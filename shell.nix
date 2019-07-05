{ pkgsSrc ? (import ./nix/pkgs.nix {}).pkgsSrc
, pkgs ? (import ./nix/pkgs.nix { inherit pkgsSrc dapptoolsOverrides; }).pkgs
, dapptoolsOverrides ? {}
, dss-deploy ? null
, doCheck ? false
}@args: with pkgs;

let
  tdds = import ./. args;
in mkShell {
  buildInputs = tdds.bins ++ [
    tdds
    sethret
    dapp2nix
  ];

  shellHook = ''
    setup-env() {
      . ${tdds}/lib/setup-env.sh
    }
    export -f setup-env
    setup-env || echo Re-run setup script with \'setup-env\'
  '';
}
