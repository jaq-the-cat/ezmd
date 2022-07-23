int getNumericFrameSize(int frameSize) {
    const int headerSize = 10;
    const int encodingSize = 1;

    return headerSize +
        encodingSize +
        frameSize;
}

int getStringFrameSize(int frameSize) {
    int headerSize = 10;
    int encodingSize = 1;
    int bomSize = 2;
    int frameUtf16Size = frameSize * 2;

    return headerSize +
        encodingSize +
        bomSize +
        frameUtf16Size;
}

int getPictureFrameSize(int pictureSize, int mimeTypeSize, int descriptionSize, bool useUnicodeEncoding) {
    int headerSize = 10;
    int encodingSize = 1;
    int separatorSize = 1;
    int pictureTypeSize = 1;
    int bomSize = 2;
    int encodedDescriptionSize = useUnicodeEncoding ?
        bomSize + (descriptionSize + separatorSize) * 2 :
        descriptionSize + separatorSize;

    return headerSize +
        encodingSize +
        mimeTypeSize +
        separatorSize +
        pictureTypeSize +
        encodedDescriptionSize +
        pictureSize;
}

int getCommentFrameSize(descriptionSize, textSize) {
    int headerSize = 10;
    int encodingSize = 1;
    int languageSize = 3;
    int bomSize = 2;
    int descriptionUtf16Size = descriptionSize * 2;
    int separatorSize = 2;
    int textUtf16Size = textSize * 2;

    return headerSize +
        encodingSize +
        languageSize +
        bomSize +
        descriptionUtf16Size +
        separatorSize +
        bomSize +
        textUtf16Size;
}

int getPrivateFrameSize(int idSize, int dataSize) {
    int headerSize = 10;
    int separatorSize = 1;

    return headerSize +
        idSize +
        separatorSize +
        dataSize;
}

int getUserStringFrameSize(int descriptionSize, int valueSize) {
    int headerSize = 10;
    int encodingSize = 1;
    int bomSize = 2;
    int descriptionUtf16Size = descriptionSize * 2;
    int separatorSize = 2;
    int valueUtf16Size = valueSize * 2;

    return headerSize +
        encodingSize +
        bomSize +
        descriptionUtf16Size +
        separatorSize +
        bomSize +
        valueUtf16Size;
}

int getUrlLinkFrameSize(int urlSize) {
    int headerSize = 10;

    return headerSize +
        urlSize;
}
