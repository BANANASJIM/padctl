import Lake
open Lake DSL

package padctl where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib Padctl where
  srcDir := "."

lean_exe oracle where
  root := `test.OracleMain
