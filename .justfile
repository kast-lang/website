default:
    echo hi

prebuild:
    just highlight

highlight:
    #!/usr/bin/env bash
    for f in static/examples/*.ks; do
        base=$(basename "$f" .ks)
        kast highlight --html "$f" |
            sed '1,/<\/style>/d' > "static/examples/$base.html"
    done

build:
    just prebuild
    zola build

serve:
    just prebuild
    zola serve