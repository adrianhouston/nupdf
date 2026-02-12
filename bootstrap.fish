#!/usr/bin/env fish

for arg in $argv
    if test $arg = --help
        echo -e "\033[1;36mUsage:\033[0m\t$(status filename) [OPTIONS]"
        echo ""
        echo -e "\033[1;33mOptions:\033[0m"
        echo -e "\t--quiet"
        echo -e "\t--(no_)update"
        echo -e "\t--(no_)patch"
        echo -e "\t--(no_)build"
        echo -e "\t--(no_)install"
        echo -e "\t--(no_)publish"
        echo -e "\t--(no_)clean"
        echo -e "\t--help"
        exit 0
    end
end

function blend
    set fg $argv[1]
    set bg $argv[2]

    set Af 0x(string sub -s 2 -l 2 $fg)
    set Rf 0x(string sub -s 4 -l 2 $fg)
    set Gf 0x(string sub -s 6 -l 2 $fg)
    set Bf 0x(string sub -s 8 -l 2 $fg)

    set af (math "$Af / 255")

    set Rb 0x(string sub -s 2 -l 2 $bg)
    set Gb 0x(string sub -s 4 -l 2 $bg)
    set Bb 0x(string sub -s 6 -l 2 $bg)

    set R (math "round($Rf * $af + $Rb * (1 - $af))")
    set G (math "round($Gf * $af + $Gb * (1 - $af))")
    set B (math "round($Bf * $af + $Bb * (1 - $af))")

    printf "#%02X%02X%02X" $R $G $B
end

set theme "#F16625"

set repo_url https://github.com/ArtifexSoftware/mupdf-android-viewer-mini.git
# set repo_url backup/mupdf-android-viewer-mini
set repo_dir (path basename -E $repo_url)
set publ_dir extras
set apk_path $repo_dir/app/build/outputs/apk/debug/app-{arm64-v8a,armeabi-v7a,universal,x86_64,x86}-debug.apk

set do_quiet 0
set do_update 0
set do_patch 0
set do_build 0
set do_install 0
set do_publish 0
set do_clean 0

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
        case --publish
            set do_publish 1
        case --clean
            set do_clean 1
        case --no_update
            set do_update 0
        case --no_patch
            set do_patch 0
        case --no_build
            set do_build 0
        case --no_install
            set do_install 0
        case --no_publish
            set do_publish 0
        case --no_clean
            set do_clean 0
    end
end

if test $do_quiet -eq 1
    set redirect ">/dev/null 2>&1"
else
    set redirect ""
end

if test -d $repo_dir
    if test $do_update -eq 1
        echo -e "\033[1;36mUpdating $repo_dir...\033[0m"
        rm -fr $repo_dir
        if test -d $repo_url
            cp -r $repo_url $repo_dir
        else
            eval git clone $repo_url $redirect
        end
    else
        echo -e "\033[1;33mSkipping update.\033[0m"
    end
else
    echo -e "\033[1;36mCloning $repo_dir...\033[0m"
    if test -d $repo_url
        cp -r $repo_url $repo_dir
    else
        eval git clone $repo_url $redirect
    end
end

if test $do_patch -eq 1
    pushd $repo_dir
    set source app/src/main/java/com/artifex/mupdf/mini/app/LibraryActivity.java
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i 's#package [^;]*;#package app.adrianhouston.nupdf;#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source app/src/main/res/drawable/ic_nupdf.xml
    mkdir -p (dirname $source) && touch $source
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="1024dp"
    android:height="1024dp"
    android:viewportWidth="16"
    android:viewportHeight="16">
    <path
        android:pathData="V 16 H 16 V 00 Z"
        android:fillColor="#FFF" />
    <path
        android:pathData="M 08 08 L 04 04 V 12 H 08 Z M 07 '(math 07 + sqrt 2)' V 11 H 05 V '(math 05 + sqrt 2)' Z"
        android:fillColor="'$theme'" />
    <path
        android:pathData="M 08 08 L 12 12 V 04 H 08 Z M 09 '(math 09 - sqrt 2)' V 05 H 11 V '(math 11 - sqrt 2)' Z"
        android:fillColor="'$theme'" />
</vector>' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source app/src/main/AndroidManifest.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        xmllint --output $source --format $source
        sed -i 's# android:label="[^"]*"# android:label="NuPDF"#' $source
        sed -i 's# android:icon="[^"]*"# android:icon="@drawable/ic_nupdf"#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source app/build.gradle
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i "s#namespace '[^']*'#namespace 'app.adrianhouston.nupdf'#" $source
        sed -i "s#versionName '[^']*'#versionName '0.1.0'#" $source
        sed -i "s#versionCode .*#versionCode 1#" $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/java/com/artifex/mupdf/mini/DocumentActivity.java
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i '\#import android.app.Activity;#a\import android.app.ActivityManager;' $source
        sed -i '\#titleLabel\.setText([^)]*);#a\setTaskDescription(new ActivityManager.TaskDescription(title, null, 0));' $source
        sed -i 's#prefs\.getBoolean("fitPage", [^)]*);#prefs.getBoolean("fitPage", true);#' $source
        sed -i 's#pageLabel\.setText([^)]*);#pageLabel.setText(String.format("%0" + String.valueOf(pageCount).length() + "d", pageNumber) + " / " + pageCount);#' $source
        sed -i '\#protected void loadPage#i\\\tprivate Bitmap invertBitmap(Bitmap src) { int width = src.getWidth(); int height = src.getHeight(); int[] pixels = new int[width * height]; src.getPixels(pixels, 0, width, 0, 0, width, height); for (int i = 0; i < pixels.length; i++) pixels[i] = (pixels[i] & 0xFF000000) | (~pixels[i] & 0x00FFFFFF); src.setPixels(pixels, 0, width, 0, 0, width, height); return src; }\n' $source
        sed -i 's#pageView\.setBitmap([^)]*);#pageView.setBitmap(((getResources().getConfiguration().uiMode \& android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES) ? invertBitmap(bitmap) : bitmap, zoom, wentBack, toggledUI, newSearchHitPage, linkBounds, linkURIs, hits);#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/java/com/artifex/mupdf/mini/PageView.java
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        sed -i '\#public class PageView#i\import androidx.core.content.ContextCompat;\n' $source
        sed -i "s#\tGestureDetector\.OnGestureListener,#\tGestureDetector.OnGestureListener, GestureDetector.OnDoubleTapListener,#" $source
        sed -i '\#protected boolean showLinks;#a\\\n\tprotected boolean wentBackward;\n\tprotected boolean wentForward;' $source
        sed -i '\#detector = [^;]*;#a\\\t\tdetector.setOnDoubleTapListener(this);' $source
        sed -i 's#maxScale = [^;]*;#maxScale = 4;#' $source
        sed -i 's#linkPaint\.setARGB([^)]*);#linkPaint.setColor(ContextCompat.getColor(getContext(), R.color.theme));\n\t\tlinkPaint.setAlpha(32);#' $source
        sed -i '\#public boolean onDown#a\\\t\twentBackward = false;\n\t\twentForward = false;' $source
        sed -i 's#public boolean onSingleTapUp#public boolean onSingleTapConfirmed#' $source
        sed -i '\#public boolean onSingleTapConfirmed#i\\\tpublic boolean onSingleTapUp(MotionEvent e) { return false; }\n' $source
        sed -i '\#public boolean onSingleTapConfirmed#i\\\tpublic boolean onDoubleTap(MotionEvent e) { if (viewScale == 1) { float x = e.getX(); float y = e.getY(); if (x <= (canvasW - bitmapW) / 2 || x < canvasW / 2 && (y <= (canvasH - bitmapH) / 2 || y >= (canvasH + bitmapH) / 2)) goBackward(); if (x >= (canvasW + bitmapW) / 2 || x > canvasW / 2 && (y <= (canvasH - bitmapH) / 2 || y >= (canvasH + bitmapH) / 2)) goForward(); if (x > (canvasW - bitmapW) / 2 && x < (canvasW + bitmapW) / 2 && y > (canvasH - bitmapH) / 2 && y < (canvasH + bitmapH) / 2 && actionListener != null) { actionListener.fitPage = !actionListener.fitPage; actionListener.loadPage(); } } else { viewScale = 1; if (bitmap != null) { bitmapW = (int)(bitmap.getWidth() * viewScale / pageScale); bitmapH = (int)(bitmap.getHeight() * viewScale / pageScale); } } invalidate(); return true; }\n' $source
        sed -i '\#public boolean onSingleTapConfirmed#i\\\tpublic boolean onDoubleTapEvent(MotionEvent e) { return false; }\n' $source
        sed -i 's#float a = [^;]*;#float a = (actionListener.fitPage) ? ((canvasW - bitmapW) / 2) : (canvasW * 1 / 5);#' $source
        sed -i '\#float a = [^;]*;#a\\\t\t\tfloat c = (canvasH - bitmapH) / 2;' $source
        sed -i 's#float b = [^;]*;#float b = (actionListener.fitPage) ? ((canvasW + bitmapW) / 2) : (canvasW * 4 / 5);#' $source
        sed -i '\#float b = [^;]*;#a\\\t\t\tfloat d = (canvasH + bitmapH) / 2;' $source
        sed -i 's#if (x <= a)#if (x <= a || x < canvasW / 2 \&\& (y <= c || y >= d))#' $source
        sed -i 's#if (x >= b)#if (x >= b || x > canvasW / 2 \&\& (y <= c || y >= d))#' $source
        sed -i 's#if (x > a && x < b && actionListener != null)#if (x > a \&\& x < b \&\& y > c \&\& y < d \&\& actionListener != null)#' $source
        sed -i '\#public synchronized boolean onScroll#a\\\t\tif (bitmapW <= canvasW && bitmapH <= canvasH) { if (!wentBackward && dx <= -25) { goBackward(); wentBackward = true; wentForward = false; } if (!wentForward && dx >= 25) { goForward(); wentForward = true; wentBackward = false; } invalidate(); }' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/drawable/button.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="@color/theme" />
    <corners android:radius="8dp" />
</shape>' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/drawable/cursor.xml
    mkdir -p (dirname $source) && touch $source
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <size android:width="2dp" />
    <solid android:color="@color/theme_alpha" />
</shape>' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/drawable/ic_chevron_left_white_24dp.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        xmllint --output $source --format $source
        sed -i 's# android:fillColor="[^"]*"# android:fillColor="@color/theme_alpha"#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/drawable/ic_chevron_right_white_24dp.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        xmllint --output $source --format $source
        sed -i 's# android:fillColor="[^"]*"# android:fillColor="@color/theme_alpha"#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/drawable/seek_thumb.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <size android:width="32dp" android:height="16dp" />
    <corners android:radius="8dp" />
    <solid android:color="@color/theme_alpha" />
</shape>' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/layout/document_activity.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android" android:id="@+id/background_layout" android:layout_width="match_parent" android:layout_height="match_parent" android:keepScreenOn="true" android:background="@color/theme_alpha">
    <com.artifex.mupdf.mini.PageView android:id="@+id/page_view" android:layout_width="match_parent" android:layout_height="match_parent" android:background="@color/theme_alpha" android:keepScreenOn="true" />
    <LinearLayout android:id="@+id/top_bar" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_alignParentTop="true" android:orientation="vertical" android:background="@null" android:visibility="gone">
        <LinearLayout android:id="@+id/action_bar" android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:visibility="gone">
            <TextView android:id="@+id/title_label" android:layout_width="0dp" android:layout_height="0dp" android:layout_gravity="center" android:layout_weight="0" android:layout_marginLeft="0dp" android:layout_marginRight="0dp" android:textColor="@color/theme_alpha" android:singleLine="true" android:ellipsize="end" android:textSize="16sp" />
            <SeekBar android:id="@+id/page_seekbar" android:layout_width="0dp" android:layout_height="32dp" android:layout_weight="1" android:layout_gravity="center" android:thumb="@drawable/seek_thumb" android:progressDrawable="@null" android:max="0" android:background="@drawable/button" android:paddingHorizontal="24dp" android:layout_marginLeft="32dp" android:layout_marginRight="16dp" android:layout_marginVertical="32dp" />
            <TextView android:id="@+id/page_label" android:layout_width="wrap_content" android:layout_height="32dp" android:layout_gravity="center" android:textColor="@color/theme_alpha" android:singleLine="true" android:ellipsize="end" android:gravity="center" android:paddingHorizontal="12dp" android:textSize="16sp" android:text="- / -" android:background="@drawable/button" android:layout_marginLeft="16dp" android:layout_marginRight="32dp" android:layout_marginVertical="32dp" />
            <ImageButton android:id="@+id/search_button" android:layout_width="0dp" android:layout_height="0dp" android:layout_gravity="center" android:background="@drawable/button" android:src="@drawable/ic_search_white_24dp" />
            <ImageButton android:id="@+id/zoom_button" android:layout_width="0dp" android:layout_height="0dp" android:layout_gravity="center" android:background="@drawable/button" android:src="@drawable/ic_zoom_out_map_white_24dp" android:visibility="gone" />
            <ImageButton android:id="@+id/layout_button" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_gravity="center" android:background="@drawable/button" android:src="@drawable/ic_format_size_white_24dp" android:visibility="gone" />
            <ImageButton android:id="@+id/outline_button" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_gravity="center" android:background="@drawable/button" android:src="@drawable/ic_toc_white_24dp" android:visibility="gone" />
        </LinearLayout>
        <LinearLayout android:id="@+id/search_bar" android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:visibility="gone">
            <ImageButton android:id="@+id/search_close_button" android:layout_width="0dp" android:layout_height="0dp" android:layout_gravity="center" android:background="@drawable/button" android:src="@drawable/ic_close_white_24dp" />
            <EditText android:id="@+id/search_text" android:layout_width="0dp" android:layout_height="32dp" android:layout_gravity="center" android:layout_weight="1" android:layout_marginLeft="32dp" android:layout_marginRight="16dp" android:layout_marginVertical="32dp" android:background="@drawable/button" android:textColor="@color/theme_alpha" android:textColorHint="@color/theme_alpha" android:singleLine="true" android:paddingHorizontal="12dp" android:textSize="16sp" android:textCursorDrawable="@drawable/cursor" android:hint="@string/text_search_hint" android:inputType="text" android:imeOptions="actionSearch" android:importantForAutofill="no" />
            <LinearLayout android:layout_width="wrap_content" android:layout_height="32dp" android:orientation="horizontal" android:background="@drawable/button" android:layout_marginLeft="16dp" android:layout_marginRight="32dp" android:layout_marginVertical="32dp" >
                <ImageButton android:id="@+id/search_backward_button" android:layout_width="wrap_content" android:layout_height="32dp" android:layout_gravity="center" android:background="@null" android:paddingHorizontal="6dp" android:src="@drawable/ic_chevron_left_white_24dp" />
                <ImageButton android:id="@+id/search_forward_button" android:layout_width="wrap_content" android:layout_height="32dp" android:layout_gravity="center" android:background="@null" android:paddingHorizontal="6dp" android:src="@drawable/ic_chevron_right_white_24dp" />
            </LinearLayout>
        </LinearLayout>
    </LinearLayout>
    <LinearLayout android:id="@+id/bottom_bar" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_alignParentBottom="true" android:orientation="horizontal" android:background="@null" android:visibility="gone">
    </LinearLayout>
</RelativeLayout>' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/values/colors.xml
    mkdir -p (dirname $source) && touch $source
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="theme">'$theme'</color>
    <color name="theme_alpha">'(blend "#20$(string sub -s 2 $theme)" "#FFFFFF")'</color>
</resources>
' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/res/values-night/colors.xml
    mkdir -p (dirname $source) && touch $source
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="theme">'$theme'</color>
    <color name="theme_alpha">'(blend "#20$(string sub -s 2 $theme)" "#000000")'</color>
</resources>
' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source lib/src/main/AndroidManifest.xml
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        xmllint --output $source --format $source
        sed -i 's# android:label="[^"]*"# android:label="NuPDF"#' $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end

    set source gradle.properties
    if test -f $source
        echo -e "\033[1;36mPatching $(basename $source)...\033[0m"
        echo 'org.gradle.java.home=/usr/lib/jvm/java-21-openjdk/' >>$source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping patch.\033[0m"
    end
    popd
else
    echo -e "\033[1;33mSkipping patch.\033[0m"
end

if test $do_build -eq 1
    echo -e "\033[1;36mBuilding $repo_dir...\033[0m"
    pushd $repo_dir
    eval ./gradlew clean $redirect
    eval ./gradlew assembleDebug $redirect
    popd
else
    echo -e "\033[1;33mSkipping build.\033[0m"
end

if test $do_install -eq 1
    set source $apk_path[1]
    if test -f $source
        echo -e "\033[1;36mInstalling $(basename $source)...\033[0m"
        eval adb install -r $source $redirect
    else
        echo -e "\033[1;35mWarning: $source not found, skipping install.\033[0m"
    end
else
    echo -e "\033[1;33mSkipping install.\033[0m"
end

if test $do_publish -eq 1
    mkdir -p $publ_dir

    set source $publ_dir/nupdf.svg
    mkdir -p (dirname $source) && touch $source
    if test -f $source
        echo -e "\033[1;36mPublishing $(basename $source)...\033[0m"
        echo '<?xml version="1.0" encoding="utf-8"?>
<svg viewBox="4 4 8 8" xmlns="http://www.w3.org/2000/svg">
    <path d="M 08 08 L 04 04 V 12 H 08 Z M 07 '(math 07 + sqrt 2)' V 11 H 05 V '(math 05 + sqrt 2)' Z" fill="'$theme'" />
    <path d="M 08 08 L 12 12 V 04 H 08 Z M 09 '(math 09 - sqrt 2)' V 05 H 11 V '(math 11 - sqrt 2)' Z" fill="'$theme'" />
</svg>' | xmllint --output $source --format -
    else
        echo -e "\033[1;35mWarning: $source not found, skipping publish.\033[0m"
    end

    for source in $apk_path
        if test -f $source
            echo -e "\033[1;36mPublishing $(basename $source)...\033[0m"
            cp $source $publ_dir/(basename $source)
        else
            echo -e "\033[1;35mWarning: $source not found, skipping publish.\033[0m"
        end
    end

    echo -e "\033[1;36mPublishing $(basename (realpath (status dirname)))...\033[0m"
    eval git add $publ_dir README.md (status filename) $redirect
    eval git commit -m \"modified: $(status filename)\" $redirect
    eval git push origin main $redirect
else
    echo -e "\033[1;33mSkipping publish.\033[0m"
end

if test $do_clean -eq 1
    set source $repo_dir
    if test -d $source
        echo -e "\033[1;36mCleaning $(basename $source)...\033[0m"
        rm -fr $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping clean.\033[0m"
    end

    set source $publ_dir
    if test -d $source
        echo -e "\033[1;36mCleaning $(basename $source)...\033[0m"
        rm -fr $source
    else
        echo -e "\033[1;35mWarning: $source not found, skipping clean.\033[0m"
    end
else
    echo -e "\033[1;33mSkipping clean.\033[0m"
end
