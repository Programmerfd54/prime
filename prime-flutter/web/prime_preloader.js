window.addEventListener('flutter-first-frame', function () {
  var el = document.getElementById('prime-preloader');
  if (!el) return;
  el.classList.add('hidden');
  setTimeout(function () { el.remove(); }, 500);
});
