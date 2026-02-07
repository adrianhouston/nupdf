#!/usr/bin/env fish

for arg in $argv
    if test $arg = --help
        echo -e "\033[1;36mUsage:\033[0m\t$(status filename) [OPTIONS]"
        echo ""
        echo -e "\033[1;33mOptions:\033[0m"
        echo -e "\t--help      \tShow this help message"
        echo -e "\t--quiet     \tSuppress output from git/gradlew/adb commands"
        echo -e "\t--update    \tUpdate existing repo from origin"
        echo -e "\t--no_update \tSkip updating"
        echo -e "\t--patch     \tApply code, manifest, layout, and drawable patches"
        echo -e "\t--no_patch  \tSkip patching"
        echo -e "\t--build     \tBuild APKs using Gradle"
        echo -e "\t--no_build  \tSkip building"
        echo -e "\t--install   \tInstall APK via adb"
        echo -e "\t--no_install\tSkip installation"
        exit 0
    end
end

set repo_url https://github.com/ArtifexSoftware/mupdf-android-viewer.git
set repo_dir (path basename -E $repo_url)
set apk_path $repo_dir/app/build/outputs/apk/debug/app-universal-debug.apk
set apk_path $repo_dir/app/build/outputs/apk/debug/app-arm64-v8a-debug.apk

set do_quiet 0
set do_update 0
set do_patch 0
set do_build 0
set do_install 0

for arg in $argv
    switch $arg
        case --quiet
            set do_quiet 1
        case --update
            set do_update 1
        case --patch
            set do_patch 1
        case --build
            set do_build 1
        case --install
            set do_install 1
        case --no_update
            set do_update 0
        case --no_patch
            set do_patch 0
        case --no_build
            set do_build 0
        case --no_install
            set do_install 0
    end
end

if test $do_quiet -eq 1
    set redirect ">/dev/null 2>&1"
else
    set redirect ""
end

if test -d $repo_dir
    if test $do_update -eq 1
        set cwd $PWD
        cd $repo_dir

        echo -e "\033[1;36mUpdating $repo_dir...\033[0m"
        eval git fetch origin $redirect
        eval git reset --hard origin/master $redirect
        eval git clean -fd $redirect
        cd $cwd
    else
        echo -e "\033[1;33mSkipping update.\033[0m"
    end
else
    echo -e "\033[1;36mCloning $repo_dir...\033[0m"
    eval git clone $repo_url $redirect
end

if test $do_patch -eq 1
    set source $repo_dir/app/src/main/java/com/artifex/mupdf/viewer/app/LibraryActivity.java
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i "s#package .*;#package app.adrianhouston.nupdf;#" $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set target $repo_dir/app/src/main/res/drawable/ic_nupdf.xml
    set source patches/(basename $target)
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        cp $source $target
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/app/src/main/AndroidManifest.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i 's#android:label="[^"]*"#android:label="NuPDF"#' $source
        sed -i 's#android:icon="[^"]*"#android:icon="@drawable/ic_nupdf"#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/app/build.gradle
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i "s#namespace '[^']*'#namespace 'app.adrianhouston.nupdf'#" $source
        sed -i "s#versionName '[^']*'#versionName '0.1.0'#" $source
        sed -i "s#versionCode .*##" $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/lib/src/main/java/com/artifex/mupdf/viewer/DocumentActivity.java
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i 's#layout\.setBackgroundColor(.*);#layout.setBackgroundColor((getResources().getConfiguration().uiMode \& android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES ? Color.BLACK : Color.WHITE);#' $source
        set mPageNumberView (sed -n '\#mPageNumberView\.setVisibility(View\.VISIBLE);#{p;q}' $source)
        sed -i '\#mPageNumberView\.setVisibility(View\.VISIBLE);#d' $source
        sed -i "\#mTopBarSwitcher\.setVisibility(View\.VISIBLE);#a\\$mPageNumberView" $source
        set mPageNumberView (sed -n '\#mPageNumberView\.setVisibility(View\.INVISIBLE);#{p;q}' $source)
        sed -i '\#mPageNumberView\.setVisibility(View\.INVISIBLE);#d' $source
        sed -i "\#mTopBarSwitcher\.setVisibility(View\.INVISIBLE);#a\\$mPageNumberView" $source
        sed -i 's#mPageNumberView\.setText(String\.format(\(.*\), "%d / %d", \(.*\)));#mPageNumberView.setText(String.format(\1, "%0" + String.valueOf(core.countPages()).length() + "d / %d", \2));#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/lib/src/main/java/com/artifex/mupdf/viewer/PageView.java
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i '\#class PageView#rpatches/invertForDarkMode.java' $source
        sed -i 's#setBackgroundColor(.*);#setBackgroundColor((getResources().getConfiguration().uiMode \& android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES ? Color.BLACK : Color.WHITE);#' $source
        sed -i 's#mEntire\.setImageBitmap(mEntireBm);#mEntire\.setImageBitmap(invertForDarkMode(mEntireBm));#' $source
        sed -i 's#mPatch\.setImageBitmap(mPatchBm);#mPatch\.setImageBitmap(invertForDarkMode(mPatchBm));#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/lib/src/main/java/com/artifex/mupdf/viewer/ReaderView.java
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i 's#float MIN_SCALE\s*=.*;#float MIN_SCALE = 1.0f;#' $source
        sed -i 's#float MAX_SCALE\s*=.*;#float MAX_SCALE = 4.0f;#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/lib/src/main/res/drawable/page_indicator.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i 's# android:radius="[^"]*"# android:radius="8dp"#' $source
        sed -i '\#<padding\b#d' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/lib/src/main/res/drawable/seek_thumb.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i 's# android:shape="[^"]*"# android:shape="rectangle"#' $source
        sed -i '\#<size\b#s# android:width="[^"]*"# android:width="32dp"#' $source
        sed -i '\#<size\b#s# android:height="[^"]*"# android:height="16dp"#' $source
        sed -i 's#<stroke\b#<solid#' $source
        sed -i '\#<solid\b#s# android:width="[^"]*"##' $source
        sed -i '\#<solid\b#i\<corners android:radius="8dp" />' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/lib/src/main/res/layout/document_activity.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        xmllint --format --output $source $source
        sed -i '\#android:id="@+id/topBar"#s# android:orientation="[^"]*"# android:orientation="horizontal"#' $source
        sed -i '\#android:id="@+id/topBar"#s# android:background="[^"]*"# android:background="@null"#' $source
        sed -i '\#android:id="@+id/actionBar"#s# android:layout_width="[^"]*"# android:layout_width="0dp"#' $source
        sed -i '\#android:id="@+id/searchBar"#s# android:layout_width="[^"]*"# android:layout_width="0dp"#' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:layout_width="[^"]*"# android:layout_width="0dp" android:layout_weight="1"#' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:layout_height="[^"]*"# android:layout_height="32dp"#' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:layout_margin="[^"]*"# android:layout_marginLeft="32dp" android:layout_marginRight="16dp" android:layout_marginVertical="32dp"#' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:paddingLeft="[^"]*"# android:paddingLeft="24dp"#' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:paddingRight="[^"]*"# android:paddingRight="24dp"#' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:paddingTop="[^"]*"##' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:paddingBottom="[^"]*"##' $source
        sed -i '\#android:id="@+id/pageSlider"#s# android:progressDrawable="[^"]*"# android:progressDrawable="@null"#' $source
        sed -i '\#android:id="@+id/pageSlider"#s#/># android:background="@drawable/page_indicator"/>#' $source
        sed -i '\#android:id="@+id/pageNumber"#s# android:layout_height="[^"]*"# android:layout_height="32dp" android:gravity="center"#' $source
        sed -i '\#android:id="@+id/pageNumber"#s# android:layout_above="[^"]*"##' $source
        sed -i '\#android:id="@+id/pageNumber"#s# android:layout_centerHorizontal="[^"]*"##' $source
        sed -i '\#android:id="@+id/pageNumber"#s# android:layout_marginBottom="[^"]*"# android:layout_marginLeft="16dp" android:layout_marginRight="32dp" android:layout_marginVertical="32dp"#' $source
        sed -i '\#android:id="@+id/pageNumber"#s#/># android:paddingLeft="12dp" android:paddingRight="12dp"/>#' $source
        set pageSlider (sed -n '\# android:id="@+id/pageSlider"#{p;q}' $source)
        sed -i '\# android:id="@+id/pageSlider"#d' $source
        sed -i "\# android:id=\"@+id/actionBar\"#i\\$pageSlider" $source
        set pageNumber (sed -n '\# android:id="@+id/pageNumber"#{p;q}' $source)
        sed -i '\# android:id="@+id/pageNumber"#d' $source
        sed -i "\# android:id=\"@+id/actionBar\"#i\\$pageNumber" $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/lib/src/main/res/values/colors.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i 's/#C0202020/#F16625/' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source $repo_dir/gradle.properties
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo 'org.gradle.java.home=/usr/lib/jvm/java-21-openjdk' >>$source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end
else
    echo -e "\033[1;33mSkipping patch.\033[0m"
end

if test $do_build -eq 1
    set cwd $PWD
    cd $repo_dir

    echo -e "\033[1;36mBuilding $repo_dir...\033[0m"
    eval ./gradlew clean $redirect
    eval ./gradlew assembleDebug $redirect
    cd $cwd
else
    echo -e "\033[1;33mSkipping build.\033[0m"
end

if test $do_install -eq 1
    if test -f $apk_path
        echo -e "\033[1;36mInstalling $(basename $apk_path)...\033[0m"
        eval adb install -r $apk_path $redirect
    else
        echo -e "\033[1;35mWarning: $apk_path not found, skipping install.\033[0m"
    end
else
    echo -e "\033[1;33mSkipping install.\033[0m"
end
