function createGradioAnimation() {

    
    window.addEventListener('message', event => {
        console.log("posted message arrived at gradio");
        console.log(event.origin);

        if (event.origin === 'https://localhost:3000' || true) {
            
            const div = document.getElementById('ProofreadContent');
            const textArea = div.getElementsByTagName("textarea")[0];
            console.log(textArea.value);
            textArea.value = event.data;
            // define event separately
            let myEvent = new Event("input")
            // update it's target to the element
            Object.defineProperty(myEvent, "target", {value: textArea})
            // dispatch the event with a non null target
            textArea.dispatchEvent(myEvent)
            console.log(event.data);
        } else {
            
            return;
        }   

    });

    var button = document.querySelector("#ChooseSelectedContent");

    if (button){
        button.addEventListener("click", function () {
            var message = "Choose selected content button was clicked!";
            // Send `message` to the parent using the postMessage method on the window.parent reference.
            window.parent.postMessage(message, "*");

            console.log("Choose selected content button was clicked from gradio");
        });
    }
    
    var container = document.createElement('div');
    container.id = 'gradio-animation';
    container.style.fontSize = '2em';
    container.style.fontWeight = 'bold';
    container.style.textAlign = 'center';
    container.style.marginBottom = '20px';

    var text = document.title;
    for (var i = 0; i < text.length; i++) {
        (function(i){
            setTimeout(function(){
                var letter = document.createElement('span');
                letter.style.opacity = '0';
                letter.style.transition = 'opacity 0.2s';
                letter.innerText = text[i];
                container.appendChild(letter);
                setTimeout(function() {
                    letter.style.opacity = '1';
                }, 50);
            }, i * 50);
        })(i);
    }
var gradioContainer = document.querySelector('.gradio-container');
    gradioContainer.insertBefore(container, gradioContainer.firstChild);

    return 'Animation created';

}