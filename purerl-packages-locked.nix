# Generated from: https://raw.githubusercontent.com/purerl/package-sets/erl-0.15.3-20220629/packages.json
# This file contains locked package versions with commit hashes
# for reproducible, pure evaluation builds.
#
# Extended set for hello-erl + test-concurrent-erl

self: {
  "arrays" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-arrays.git";
      rev = "24ac35d3598af6bfb5e479d313f9493ab4d62984"; # v6.0.0-erl1
    };
    info = {
      version = "v6.0.0-erl1";
      dependencies = [
        "bifunctors"
        "control"
        "foldable-traversable"
        "maybe"
        "nonempty"
        "partial"
        "prelude"
        "tailrec"
        "tuples"
        "unfoldable"
        "unsafe-coerce"
      ];
    };
  };

  "bifunctors" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-bifunctors.git";
      rev = "a31d0fc4bbebf19d5e9b21b65493c28b8d3fba62"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "const"
        "either"
        "newtype"
        "prelude"
        "tuples"
      ];
    };
  };

  "console" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-console.git";
      rev = "56cfd5294acb79758cf30b357751f624650f18e3"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [
        "effect"
        "prelude"
      ];
    };
  };

  "const" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-const.git";
      rev = "3a3a4bdc44f71311cf27de9bd22039b110277540"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "invariant"
        "newtype"
        "prelude"
      ];
    };
  };

  "catenable-lists" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-catenable-lists.git";
      rev = "b18278a7cd034b983187580c58a183456b5a25ee"; # v6.0.1
    };
    info = {
      version = "v6.0.1";
      dependencies = [
        "control"
        "foldable-traversable"
        "lists"
        "maybe"
        "prelude"
        "tuples"
        "unfoldable"
      ];
    };
  };

  "contravariant" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-contravariant.git";
      rev = "ae1a765f7ddbfd96ae1f12e399e46d554d8e3b38"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "const"
        "either"
        "newtype"
        "prelude"
        "tuples"
      ];
    };
  };

  "control" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-control.git";
      rev = "e3add624f8dacb4d6bec6d9ed682df692e197b5b"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [
        "newtype"
        "prelude"
      ];
    };
  };

  "distributive" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-distributive.git";
      rev = "11f3f87ca5720899e1739cedb58dd6227cae6ad5"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "identity"
        "newtype"
        "prelude"
        "tuples"
        "type-equality"
      ];
    };
  };

  "effect" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-effect.git";
      rev = "69ba78cd96a27a0af6a723d255dc05a32c6eaa43"; # v3.0.0-erl1
    };
    info = {
      version = "v3.0.0-erl1";
      dependencies = [ "prelude" ];
    };
  };

  "either" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-either.git";
      rev = "c1a1af35684f10eecaf6ac7d38dbf6bd48af2ced"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "control"
        "invariant"
        "maybe"
        "prelude"
      ];
    };
  };

  "enums" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-enums.git";
      rev = "9c3ec61d03c04642af91e2ac72500cdd6009bd98"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [
        "control"
        "either"
        "gen"
        "maybe"
        "newtype"
        "nonempty"
        "partial"
        "prelude"
        "tuples"
        "unfoldable"
      ];
    };
  };

  "exists" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-exists.git";
      rev = "c34820f8b2d15be29abdd5097c3d636f5df8f28c"; # v5.1.0
    };
    info = {
      version = "v5.1.0";
      dependencies = [ "unsafe-coerce" ];
    };
  };

  "exceptions" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-exceptions.git";
      rev = "e57e9598bc327f4e8301136e0af53335fbb1973f"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [
        "effect"
        "either"
        "maybe"
        "prelude"
      ];
    };
  };

  "foldable-traversable" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-foldable-traversable.git";
      rev = "444a611d64800a82259b9c22999330b6a7b48a3d"; # v5.0.1-erl1
    };
    info = {
      version = "v5.0.1-erl1";
      dependencies = [
        "bifunctors"
        "const"
        "control"
        "either"
        "functors"
        "maybe"
        "newtype"
        "orders"
        "prelude"
        "tuples"
      ];
    };
  };

  "functions" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-functions.git";
      rev = "6f0854f056b5295835db2cc3d06bf8763c181536"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [ "prelude" ];
    };
  };

  "gen" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-gen.git";
      rev = "85c369f56545a3de834b7e7475a56bc9193bb4b4"; # v3.0.0
    };
    info = {
      version = "v3.0.0";
      dependencies = [
        "either"
        "foldable-traversable"
        "identity"
        "maybe"
        "newtype"
        "nonempty"
        "prelude"
        "tailrec"
        "tuples"
        "unfoldable"
      ];
    };
  };

  "functors" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-functors.git";
      rev = "56e9889b6939264c4707ad48356419a147493c3e"; # v4.1.1
    };
    info = {
      version = "v4.1.1";
      dependencies = [
        "bifunctors"
        "const"
        "contravariant"
        "control"
        "distributive"
        "either"
        "invariant"
        "maybe"
        "newtype"
        "prelude"
        "profunctor"
        "tuples"
        "unsafe-coerce"
      ];
    };
  };

  "free" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-free.git";
      rev = "3c90f01172329052d9af6ef3114c951f752221e3"; # v6.0.1
    };
    info = {
      version = "v6.0.1";
      dependencies = [
        "catenable-lists"
        "control"
        "distributive"
        "either"
        "exists"
        "foldable-traversable"
        "invariant"
        "lazy"
        "maybe"
        "prelude"
        "tailrec"
        "transformers"
        "tuples"
        "unsafe-coerce"
      ];
    };
  };

  "freeap" = {
    src.git = {
      repo = "https://github.com/ethul/purescript-freeap.git";
      rev = "7900fa09a5da2122d69aec3a4ff176015e40bb2b"; # v6.0.0
    };
    info = {
      version = "v6.0.0";
      dependencies = [
        "const"
        "exists"
        "gen"
        "lists"
      ];
    };
  };

  "identity" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-identity.git";
      rev = "5c150ac5ee4fa6f145932f6322a1020463dae8e9"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "control"
        "invariant"
        "newtype"
        "prelude"
      ];
    };
  };

  "invariant" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-invariant.git";
      rev = "c421b49dec7a1511073bb408a08bdd8c9d17d7b1"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "control"
        "prelude"
      ];
    };
  };

  "lazy" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-lazy.git";
      rev = "11a8a4fa99ef88daf36458b163010179c633168e"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [
        "control"
        "foldable-traversable"
        "invariant"
        "prelude"
      ];
    };
  };

  "lists" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-lists.git";
      rev = "f07a986d14df3dcea57067b7f10fbbca4783be00"; # v6.0.1
    };
    info = {
      version = "v6.0.1";
      dependencies = [
        "bifunctors"
        "control"
        "foldable-traversable"
        "lazy"
        "maybe"
        "newtype"
        "nonempty"
        "partial"
        "prelude"
        "tailrec"
        "tuples"
        "unfoldable"
      ];
    };
  };

  "maybe" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-maybe.git";
      rev = "8e96ca0187208e78e8df6a464c281850e5c9400c"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "control"
        "invariant"
        "newtype"
        "prelude"
      ];
    };
  };

  "newtype" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-newtype.git";
      rev = "7b292fcd2ac7c4a25d7a7a8d3387d0ee7de89b13"; # v4.0.0
    };
    info = {
      version = "v4.0.0";
      dependencies = [
        "prelude"
        "safe-coerce"
      ];
    };
  };

  "nonempty" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-nonempty.git";
      rev = "d3e91e3d6e06e5bdcc5b2c21c8e5d0f9b946bb9e"; # v6.0.0
    };
    info = {
      version = "v6.0.0";
      dependencies = [
        "control"
        "foldable-traversable"
        "maybe"
        "prelude"
        "tuples"
        "unfoldable"
      ];
    };
  };

  "orders" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-orders.git";
      rev = "c25b7075426cf82bcb960495f28d2541c9a75510"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "newtype"
        "prelude"
      ];
    };
  };

  "partial" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-partial.git";
      rev = "19b45492d8807bd242a6cbbd68de620f62173561"; # v3.0.0-erl1
    };
    info = {
      version = "v3.0.0-erl1";
      dependencies = [ ];
    };
  };

  "prelude" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-prelude.git";
      rev = "75a86f361270985ae983b59d4a69c0513b7f1cb1"; # v5.0.1-erl1
    };
    info = {
      version = "v5.0.1-erl1";
      dependencies = [ ];
    };
  };

  "profunctor" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-profunctor.git";
      rev = "4551b8e437a00268cc9b687cbe691d75e812e82b"; # v5.0.0
    };
    info = {
      version = "v5.0.0";
      dependencies = [
        "control"
        "distributive"
        "either"
        "exists"
        "invariant"
        "newtype"
        "prelude"
        "tuples"
      ];
    };
  };

  "refs" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-refs.git";
      rev = "1a921991d2c0900c4582d69586bfbd5ce3d53952"; # v5.0.0-erl2
    };
    info = {
      version = "v5.0.0-erl2";
      dependencies = [
        "effect"
        "prelude"
      ];
    };
  };

  "record" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-record.git";
      rev = "539eb726cd7bdfcd95bf8bca20b3aed993006919"; # v3.0.0-erl1
    };
    info = {
      version = "v3.0.0-erl1";
      dependencies = [
        "functions"
        "typelevel-prelude"
        "unsafe-coerce"
      ];
    };
  };

  "safe-coerce" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-safe-coerce.git";
      rev = "e719defd227d932da067a1f0d62a60b3d3ff3637"; # v1.0.0
    };
    info = {
      version = "v1.0.0";
      dependencies = [ "unsafe-coerce" ];
    };
  };

  "tailrec" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-tailrec.git";
      rev = "a865d0787fef54e7350d8c1e8d2e9ed94fae47b7"; # v5.0.1-erl1
    };
    info = {
      version = "v5.0.1-erl1";
      dependencies = [
        "bifunctors"
        "effect"
        "either"
        "identity"
        "maybe"
        "partial"
        "prelude"
        "refs"
      ];
    };
  };

  "transformers" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-transformers.git";
      rev = "1e5d4193b38c613c97ea1ebdb721c6b94cd8c50a"; # v5.2.0
    };
    info = {
      version = "v5.2.0";
      dependencies = [
        "control"
        "distributive"
        "effect"
        "either"
        "exceptions"
        "foldable-traversable"
        "identity"
        "lazy"
        "maybe"
        "newtype"
        "prelude"
        "tailrec"
        "tuples"
        "unfoldable"
      ];
    };
  };

  "tuples" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-tuples.git";
      rev = "04630b287d453158b2b95c4be695dfe9fdd83a12"; # v6.0.1
    };
    info = {
      version = "v6.0.1";
      dependencies = [
        "control"
        "invariant"
        "prelude"
      ];
    };
  };

  "type-equality" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-type-equality.git";
      rev = "0525b7d39e0fbd81b4209518139fb8ab02695774"; # v4.0.1
    };
    info = {
      version = "v4.0.1";
      dependencies = [ ];
    };
  };

  "typelevel-prelude" = {
    src.git = {
      repo = "https://github.com/purescript/purescript-typelevel-prelude.git";
      rev = "83ddcdb23d06c8d5ea6196596a70438f42cd4afd"; # v6.0.0
    };
    info = {
      version = "v6.0.0";
      dependencies = [
        "prelude"
        "type-equality"
      ];
    };
  };

  "unfoldable" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-unfoldable.git";
      rev = "5d3b6ac48757c9aa93f6410f86266034fd510599"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [
        "foldable-traversable"
        "maybe"
        "partial"
        "prelude"
        "tuples"
      ];
    };
  };

  "unsafe-coerce" = {
    src.git = {
      repo = "https://github.com/purerl/purescript-unsafe-coerce.git";
      rev = "7150d261d40cd92112e8c2064124c5682627f137"; # v5.0.0-erl1
    };
    info = {
      version = "v5.0.0-erl1";
      dependencies = [ ];
    };
  };

  "variant" = {
    src.git = {
      repo = "https://github.com/natefaubion/purescript-variant.git";
      rev = "3f12411ede5edd342d25340c1babce9ae81d6793"; # v7.0.3
    };
    info = {
      version = "v7.0.3";
      dependencies = [
        "enums"
        "lists"
        "maybe"
        "partial"
        "prelude"
        "record"
        "tuples"
        "unsafe-coerce"
      ];
    };
  };

}
