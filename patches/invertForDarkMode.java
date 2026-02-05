private Bitmap invertForDarkMode(Bitmap src) {
    if ((getContext().getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK) != android.content.res.Configuration.UI_MODE_NIGHT_YES) {
        return src;
    }

    Bitmap bitmap = src.isMutable() ? src : src.copy(src.getConfig(), true);

    int w = bitmap.getWidth(), h = bitmap.getHeight();

    int[] pixels = new int[w * h];

    bitmap.getPixels(pixels, 0, w, 0, 0, w, h);

    for (int i = 0; i < pixels.length; i++) {
        pixels[i] = (pixels[i] & 0xFF000000) | (~pixels[i] & 0x00FFFFFF);
    }

    bitmap.setPixels(pixels, 0, w, 0, 0, w, h);

    return bitmap;
}
