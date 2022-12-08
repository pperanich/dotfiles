{ inputs, lib, pkgs, config, outputs, ... }:
{
  programs.texlive = {
    enable = true;
    extraPackages = tpkgs:
      { inherit (tpkgs)
        ae amscls amsfonts amsmath anysize arabxetex atbegshi attachfile2
        atveryend automata auxhook awesomebox babel babel-basque babel-czech
        babel-danish babel-dutch babel-english babel-finnish babel-french
        babel-german babel-hungarian babel-italian babel-norsk babel-polish
        babel-portuges babel-spanish babel-swedish babelbib bbcard beamer bibtex
        bidi-atbegshi bidicontour bidipagegrid bidipresentation bidishadowtext
        bigintcalc bitset blockdraw_mp bookmark booktabs bpolynomial breqn
        businesscard-qrcode capt-of caption carlisle catchfile cite cm cmap
        cmarrows collection-basic collection-latex collection-latexrecommended
        collection-metapost collection-xetex colorprofiles colortbl cqubeamer
        crop ctable ctablestack dehyph drv dviincl dvipdfmx dvips dvipng ec emp enctex
        environ epsincl epstopdf-pkg eso-pic etex etex-pkg etexcmds etoolbox
        euenc euler eurosym everysel everyshi expressg exteps extsizes fancybox
        fancyhdr fancyref fancyvrb featpost feynmf feynmp-auto filehook firstaid
        fix2col fixlatvian fiziko float font-change-xetex fontbook fontspec
        fontwrap footnotehyper fp framed fvextra garrigues geometry
        gettitlestring glyphlist gmp graphics graphics-cfg graphics-def grfext
        grffile hatching hologo hopatch hycolor hyperref hyph-utf8 hyphen-base
        hyphen-basque hyphen-czech hyphen-danish hyphen-dutch hyphen-english
        hyphen-finnish hyphen-french hyphen-german hyphen-hungarian
        hyphen-italian hyphen-norwegian hyphen-polish hyphen-portuguese
        hyphen-spanish hyphen-swedish hyphenex ifplatform iftex index infwarerr
        intcalc interchar jknapltx knuth-lib knuth-local koma-script kpathsea
        kvdefinekeys kvoptions kvsetkeys l3backend l3experimental l3kernel
        l3packages latex latex-base-dev latex-bin latex-firstaid-dev latex-fonts
        latexbug latexconfig latexmk latexmp letltxmacro lineno listings lm
        lm-math ltxcmds ltxmisc lua-alt-getopt lua-uni-algos luahbtex lualibs
        luaotfload luatex luatexbase lwarp makecmds makeindex mathspec mathtools
        mcf2graph mdwtools memoir metafont metago metalogo metaobj metaplot
        metapost metapost-colorbrewer metauml mflogo mfnfss mfpic mfpic4ode
        mfware microtype minim-hatching minted modes mp3d mparrows mpattern
        mpcolornames mpgraphics mptopdf mptrees ms na-position natbib newfloat
        ntgclass oberdiek pagesel parskip pdfescape pdflscape
        pdfmanagement-testphase pdfpages pdftex pdftexcmds pgf philokalia
        piechartmp plain polyglossia psfrag pslatex psnfss pspicture ptext
        ragged2e rcs realscripts refcount repere rerunfilecheck revtex roex
        roundrect sansmath scheme-basic scheme-infraonly scheme-minimal
        scheme-small section seminar sepnum setspace shapes simple-resume-cv
        simple-thesis-dissertation slideshow splines stringenc suanpan subfig
        svg symbol synctex tcolorbox tetragonos tex tex-ini-files texlive-common
        texlive-en texlive-msg-translations texlive-scripts textcase textpath
        threeddice thumbpdf times tipa tlshell tools translator transparent
        trimspaces typehtml ucharcat ucharclasses ulem underscore unicode-bidi
        unicode-data unicode-math uniquecounter unisugar upquote url wrapfig
        xcolor xdvi xebaposter xechangebar xecolor xecyr xeindex xelatex-dev
        xesearch xespotcolor xetex xetex-itrans xetex-pstricks xetex-tibetan
        xetexconfig xetexfontinfo xetexko xevlna xkeyval xltxtra xpatch xstring
        xunicode zapfding zbmath-review-template;
      };
  };
}
