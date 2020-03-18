safari.extension.dispatchMessage("load")

safari.self.addEventListener("message", ({name, message}) => {
  const handler = messageHandlers[name]
  if (handler) {
    handler(message)
  }
})

const messageHandlers = {
  onload: message => {
    Object.entries(message).forEach(([fileType, files]) => {
      files.forEach(([fileName, content]) => {
        console.log(`Injecting ${fileName}`)
        fileTypeHandlers[fileType](content)
      })
    })
  },
}

const fileTypeHandlers = {
  js: content => {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", () => {
        eval(content)
      })
    } else {
      eval(content)
    }
  },
  css: content => {
    const node = document.createElement("style")
    node.textContent = content
    document.head.appendChild(node)
  },
}
