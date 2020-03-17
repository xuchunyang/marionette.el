# Control Firefox via the Marionette Protocol

marionette.el lets you control the Firefox web browser via the [Marionette Protocol](https://firefox-source-docs.mozilla.org/testing/marionette/Protocol.html).

To use this library, you need to have a running Firefox instance with the
marionette protocol enabled. To do this, all you have to do is run the firefox
binary with the `-marionette` flag. E.g.,

    $ /Applications/Firefox.app/Contents/MacOS/firefox -marionette
    # For macOS (open(1) does not block your terminal)
    $ open -a Firefox --args -marionette

``` emacs-lisp
;; Get Title of http://example.com
(marionette-with-page
 (lambda (proc)
   (marionette-request proc 'Navigate :url "http://example.com")
   (marionette-request proc 'GetTitle)))
;; => ((value . "Example Domain"))
```

``` emacs-lisp
;; Take Screenshot of http://example.com, save to example.com.png
(marionette-with-page
 (lambda (proc)
   (marionette-request proc 'Navigate :url "http://example.com")
   (let-alist (marionette-request proc 'TakeScreenshot :full t)
     (let ((coding-system-for-write 'binary))
       (write-region
        (base64-decode-string .value)
        nil
        "example.com.png")))))
```

## References

- [Marionette — Mozilla Source Tree Docs 76.0a1 documentation](https://firefox-source-docs.mozilla.org/testing/marionette/index.html)
- [gecko-dev/marionette.py at master · mozilla/gecko-dev](https://github.com/mozilla/gecko-dev/blob/master/testing/marionette/client/marionette_driver/marionette.py)
- [WebDriver](https://w3c.github.io/webdriver/)
- [Marionette - Racket](https://docs.racket-lang.org/marionette/index.html)
