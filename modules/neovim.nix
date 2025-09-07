{ ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    configure = {
      customRC = ''
      set nu rnu

      map n nzzzv
      map N Nzzzv
      map <C-d> <C-d>zz
      map <C-u> <C-u>zz

      imap jk <Esc>
    '';
    };
  };
}
