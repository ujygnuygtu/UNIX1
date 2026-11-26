#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Ошибка: необходимо указать один исходный файл"
    echo "Использование ./build.sh <исходный_файл>"
    exit 1
fi

SOURCE=$1

if [ ! -f "$SOURCE" ]; then
    echo "Ошибка: исходный файл не существует"
    exit 2
fi

if [ ! -r "$SOURCE" ]; then
    echo "Ошибка: нет прав на чтение исходного файла"
    exit 3
fi

SOURCE_DIR=$(dirname "$SOURCE")
SOURCE_NAME=$(basename "$SOURCE")

SOURCE_DIR=$(cd "$SOURCE_DIR" 2>/dev/null && pwd) || exit 2

SOURCE_PATH="$SOURCE_DIR/$SOURCE_NAME"

OUTPUT=$(awk '
{
    if (match($0, /Output:[[:space:]]*[[:alnum:]_.-]+/)) {
        result = substr($0, RSTART, RLENGTH)
        sub(/^Output:[[:space:]]*/, "", result)
        print result
        exit
    }
}' "$SOURCE_PATH")

if [ -z "$OUTPUT" ]; then
    echo "Ошибка: комментарий Output не найден"
    exit 4
fi

if [ "$OUTPUT" = "$SOURCE_NAME" ]; then
    echo "Ошибка: имя выходного файла совпадает с исходным"
    exit 5
fi

case "$SOURCE_NAME" in
    *.c)
        BUILD_TYPE="c"
        ;;
    *.cpp|*.cc|*.cxx)
        BUILD_TYPE="cpp"
        ;;
    *.tex)
        BUILD_TYPE="tex"
        ;;
    *)
        echo "Ошибка: неподдерживаемый тип файла"
        exit 6
        ;;
esac

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/build.XXXXXX") || {
    echo "Ошибка: не удалось создать временную директорию"
    exit 7
}

cleanup()
{
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup 0 

trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cp "$SOURCE_PATH" "$TMP_DIR/$SOURCE_NAME" || {
    echo "Ошибка: не удалось скопировать исходный файл"
    exit 8
}

cd "$TMP_DIR" || {
    echo "Ошибка: не удалось перейти во временную директорию"
    exit 9
}

case "$BUILD_TYPE" in 

    c)
        cc "$SOURCE_NAME" -o "$OUTPUT"
        STATUS=$?
        ;;
    cpp)
        c++ "$SOURCE_NAME" -o "$OUTPUT"
        STATUS=$?
        ;;
    tex)
        pdflatex -interaction=nonstopmode "$SOURCE_NAME"
        STATUS=$?

        if [ "$STATUS" -eq 0 ]; then
            mv "${SOURCE_NAME%.tex}.pdf" "$OUTPUT"
            STATUS=$?
        fi
        ;;
esac

if [ "$STATUS" -ne 0 ]; then 
    echo "Ошибка: сборка завершилась неудачно"
    echo "Код ошибки компилятора: $STATUS"
    exit 10
fi

if [ ! -f "$OUTPUT" ]; then
    echo "Ошибка: конечный файл не был создан"
    exit 11
fi

cp "$OUTPUT" "$SOURCE_DIR/$OUTPUT" || {
    echo "Ошибка: не удалось сохранить конечный файл"
    exit 12
}

echo "Сборка успешно завершена"
echo "Результат: $SOURCE_DIR/$OUTPUT"

exit 0