# Default import pinned pkgs
{ pkgsSrc ? (import ./nix/pkgs.nix {}).pkgsSrc
, pkgs ? (import ./nix/pkgs.nix { inherit pkgsSrc; }).pkgs
, dss-deploy ? null
, doCheck ? false
, githubAuthToken ? null
}: with pkgs;

let
  inherit (builtins) replaceStrings;
  inherit (lib) mapAttrs optionalAttrs id;
  # Get contract dependencies from lock file
  inherit (callPackage ./nix/dapp.nix {}) specs packageSpecs;
  inherit (specs.this) deps;
  optinalFunc = x: fn: if x then fn else id;

  # Update GitHub repo URLs and add a auth token for private repos
  addGithubToken = spec: spec // (let
    url = replaceStrings
      [ "https://github.com" ]
      [ "https://${githubAuthToken}@github.com" ]
      spec.repo'.url;
  in rec {
    repo' = spec.repo' // { inherit url; };
    src' = fetchGit repo';
    src = "${src'}/src";
  });

  # Recursively add GitHub auth token to spec
  recAddGithubToken = spec: addGithubToken (spec // {
    deps = mapAttrs (_: recAddGithubToken) spec.deps;
  });

  # Import deploy scripts from dss-deploy
  dss-deploy' = if isNull dss-deploy
    then import deps.dss-deploy.src' { inherit doCheck; }
    else dss-deploy;

  # Create derivations from lock file data
  packages = packageSpecs (mapAttrs (_: spec:
    (optinalFunc (! isNull githubAuthToken) recAddGithubToken)
      (spec // { inherit doCheck; })
  ) deps);

in makerScriptPackage {
  name = "testchain-dss-deploy-scripts";

  # Specify files to add to build environment
  src = lib.sourceByRegex ./. [
    "deploy-.*"
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
