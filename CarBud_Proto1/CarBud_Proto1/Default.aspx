<%@ Page Title="CarBud Rentals" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="CarBud_Proto1._Default" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <section class="hero">
        <h1>Not sure which car you need?</h1>
        <p>Answer five quick questions and CarBud, our AI assistant, recommends the three cars that suit your trip best, and tells you why.</p>
        <div class="actions">
            <a class="btn" href="Chat.aspx">Ask CarBud</a>
            <a class="btn btn-outline" href="Cars.aspx">Browse all cars</a>
        </div>
    </section>

    <section class="steps">
        <div class="step">
            <span class="num">1</span>
            <h3>Tell us about your trip</h3>
            <p>Passengers, distance, luggage, budget and purpose.</p>
        </div>
        <div class="step">
            <span class="num">2</span>
            <h3>Get three matches</h3>
            <p>Each one comes with a plain explanation of why it fits.</p>
        </div>
        <div class="step">
            <span class="num">3</span>
            <h3>Book in one click</h3>
            <p>Pick your dates and the car is yours.</p>
        </div>
    </section>
</asp:Content>
