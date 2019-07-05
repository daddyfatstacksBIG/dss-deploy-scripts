# Default import pinned pkgs
{ pkgsSrc ? (import ./nix/pkgs.nix {}).pkgsSrc
, pkgs ? (import ./nix/pkgs.nix { inherit pkgsSrc dapptoolsOverrides; }).pkgs
, dapptoolsOverrides ? {}
, dss-deploy ? null
, doCheck ? false
}: with pkgs;

let
  inherit (lib) mapAttrs;
  # Get contract dependencies from lock file
  inherit (callPackage ./nix/dapp.nix {}) specs packageSpecs;
  inherit (specs.this) deps;

  # Import deploy scripts from dss-deploy
  dss-deploy' = if isNull dss-deploy
    then import deps.dss-deploy.src' { inherit doCheck; }
    else dss-deploy;

  # Create derivations from lock file data
  packages = packageSpecs (mapAttrs (_: v: v // { inherit doCheck; }) (deps // {
    # Set specific solc versions for some contract derivations
    multicall = deps.multicall   // { solc = solc-versions.solc_0_4_25; };
    vote-proxy = deps.vote-proxy // { solc = solc-versions.solc_0_4_25; };
  }));
in makerScriptPackage {
  name = "testchain-dss-deploy-scripts";

  # Specify files to add to build environment
  src = lib.sourceByRegex ./. [
    ".*deploy"
    ".*\.json"
    ".*scripts.*"
    ".*lib.*"
  ];

  solidityPackages = builtins.attrValues packages;

  extraBins = [
    dss-deploy'
  ];

  scriptEnv = {
    SKIP_BUILD = true;
  };
}
