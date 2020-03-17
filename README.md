# Control Firefox via the Marionette Protocol

``` emacs-lisp
;; Get Title of http://example.com
(marionette
 (lambda (proc)
   (marionette-request proc 'Navigate :url "http://example.com")
   (marionette-request proc 'GetTitle)))
;; => ((value . "Example Domain"))
```

``` emacs-lisp
;; Take Screenshot of http://example.com, save to example.com.png
(marionette
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
