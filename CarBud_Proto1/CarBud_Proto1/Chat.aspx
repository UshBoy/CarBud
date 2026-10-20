<%@ Page Title="Ask CarBud - CarBud Rentals" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Chat.aspx.cs" Inherits="CarBud_Proto1.Chat" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">

    <%-- STEP 1: the conversation. The questions are shown one by one in the browser. --%>
    <asp:Panel ID="pnlAsk" runat="server">
        <div class="chat">
            <div class="chat-head"><strong>CarBud</strong> <span class="muted">your car-finding assistant</span></div>
            <div id="chatLog" class="chat-log"></div>
            <noscript><p class="error chat-pad">Please turn on JavaScript to chat with CarBud.</p></noscript>
        </div>

        <%-- Hidden fields: the questions go to the browser, the answers come back --%>
        <asp:HiddenField ID="hfQuestions" runat="server" ClientIDMode="Static" />
        <asp:HiddenField ID="hfAnswers" runat="server" ClientIDMode="Static" />
        <asp:HiddenField ID="hfNotes" runat="server" ClientIDMode="Static" />
        <asp:Button ID="btnSubmit" runat="server" ClientIDMode="Static" CssClass="hidden" Text="Find my cars" OnClick="btnSubmit_Click" />
    </asp:Panel>

    <%-- STEP 2: the recommendations --%>
    <asp:Panel ID="pnlResult" runat="server" Visible="false">
        <div class="chat">
            <div class="chat-head"><strong>CarBud</strong> <span class="muted">your car-finding assistant</span></div>
            <div class="chat-log">
                <div class="bubble bubble-bot">Hi, I'm CarBud! Answer five quick questions and I'll find the cars that suit your trip best.</div>
                <asp:Repeater ID="rptTranscript" runat="server">
                    <ItemTemplate>
                        <div class="bubble bubble-bot"><%#: Eval("Question") %></div>
                        <div class="bubble bubble-user"><%#: Eval("Answer") %></div>
                    </ItemTemplate>
                </asp:Repeater>
                <asp:Panel ID="pnlNotesBubble" runat="server" CssClass="bubble bubble-user" Visible="false">
                    <asp:Literal ID="litNotes" runat="server" />
                </asp:Panel>
                <div class="bubble bubble-bot"><asp:Literal ID="litIntro" runat="server" /></div>
            </div>
        </div>

        <div class="rec-list">
            <asp:Repeater ID="rptResults" runat="server">
                <ItemTemplate>
                    <div class="rec-card">
                        <div class="rec-head">
                            <div>
                                <div class="rec-rank"><%#: Eval("RankLabel") %></div>
                                <h3><%#: Eval("Name") %></h3>
                                <div class="car-type"><%#: Eval("CarType") %></div>
                            </div>
                            <div class="rec-score"><strong><%#: Eval("Score") %></strong>/100 match</div>
                        </div>
                        <ul class="specs">
                            <li><%#: Eval("Seats") %> seats</li>
                            <li><%#: Eval("BootLitres") %> L boot</li>
                            <li><%#: Eval("FuelType") %></li>
                            <li>Comfort <%#: Eval("Comfort") %>/5</li>
                        </ul>
                        <p class="rec-why"><%#: Eval("Reason") %></p>
                        <div class="car-foot">
                            <span class="price"><%#: Eval("PricePerDay") %> kr <small>/ day</small></span>
                            <a class="btn btn-small" href='CarDetails.aspx?id=<%# Eval("CarID") %>'>Book this car</a>
                        </div>
                    </div>
                </ItemTemplate>
            </asp:Repeater>
        </div>

        <p class="ai-note"><asp:Literal ID="litAiNote" runat="server" /></p>
        <div class="chat-actions"><a class="btn btn-outline" href="Chat.aspx">Start again</a></div>
    </asp:Panel>

    <%-- Shown if something went wrong --%>
    <asp:Panel ID="pnlError" runat="server" Visible="false" CssClass="empty">
        <asp:Literal ID="litError" runat="server" /> <a href="Chat.aspx">Start again</a>
    </asp:Panel>

    <script>
        // The conversation in the browser: one question at a time, with clickable answers.
        (function () {
            var log = document.getElementById('chatLog');
            var questionsField = document.getElementById('hfQuestions');
            if (!log || !questionsField) { return; }

            var questions = JSON.parse(questionsField.value || '[]');
            var answers = [];
            var step = 0;

            function scrollDown(element) {
                element.scrollIntoView({ behavior: 'smooth', block: 'end' });
            }

            function bubble(who, text) {
                var div = document.createElement('div');
                div.className = 'bubble bubble-' + who;
                div.textContent = text;
                log.appendChild(div);
                scrollDown(div);
                return div;
            }

            function choices(options, onPick) {
                var wrap = document.createElement('div');
                wrap.className = 'choices';
                options.forEach(function (option) {
                    var button = document.createElement('button');
                    button.type = 'button';
                    button.className = 'choice';
                    button.textContent = option.text;
                    button.addEventListener('click', function () {
                        log.removeChild(wrap);
                        onPick(option);
                    });
                    wrap.appendChild(button);
                });
                log.appendChild(wrap);
                scrollDown(wrap);
            }

            function askNext() {
                if (step < questions.length) {
                    var question = questions[step];
                    bubble('bot', question.text);
                    choices(question.options, function (option) {
                        bubble('user', option.text);
                        answers.push(option.id);
                        step++;
                        setTimeout(askNext, 350);
                    });
                } else {
                    askNotes();
                }
            }

            function askNotes() {
                bubble('bot', 'Anything else I should know? For example "travelling with a dog" or "I prefer electric". You can skip this.');

                var wrap = document.createElement('div');
                wrap.className = 'notes';
                var input = document.createElement('input');
                input.type = 'text';
                input.maxLength = 300;
                input.placeholder = 'Type here (optional)';
                var go = document.createElement('button');
                go.type = 'button';
                go.className = 'btn';
                go.textContent = 'Find my cars';
                var skip = document.createElement('button');
                skip.type = 'button';
                skip.className = 'btn btn-outline';
                skip.textContent = 'Skip';

                function finish(text) {
                    text = (text || '').replace(/[<>]/g, '').trim();
                    log.removeChild(wrap);
                    if (text) { bubble('user', text); }
                    document.getElementById('hfAnswers').value = answers.join(',');
                    document.getElementById('hfNotes').value = text;
                    bubble('bot', 'Let me think about that').classList.add('thinking');
                    document.getElementById('btnSubmit').click();
                }

                go.addEventListener('click', function () { finish(input.value); });
                skip.addEventListener('click', function () { finish(''); });
                input.addEventListener('keydown', function (e) {
                    if (e.key === 'Enter') { e.preventDefault(); finish(input.value); }
                });

                wrap.appendChild(input);
                wrap.appendChild(go);
                wrap.appendChild(skip);
                log.appendChild(wrap);
                scrollDown(wrap);
                input.focus();
            }

            bubble('bot', "Hi, I'm CarBud! Answer five quick questions and I'll find the cars that suit your trip best.");
            setTimeout(askNext, 500);
        })();
    </script>
</asp:Content>
